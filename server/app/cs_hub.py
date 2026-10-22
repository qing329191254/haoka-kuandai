"""在线客服 WebSocket 连接中心：按会话房间广播，管理端另有大厅收列表更新。"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Any, Literal

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect, WebSocketState

from app.cs_chat import cs_conversation_out, cs_message_out
from app.models import CsConversation, CsMessage

logger = logging.getLogger(__name__)

Role = Literal["user", "admin"]


@dataclass
class CsPeer:
    ws: WebSocket
    role: Role
    conversation_ids: set[str] = field(default_factory=set)


class CsHub:
    def __init__(self) -> None:
        self._peers: set[CsPeer] = set()
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    async def connect(self, ws: WebSocket, *, role: Role, conversation_id: str = "") -> CsPeer:
        await ws.accept()
        peer = CsPeer(ws=ws, role=role)
        if conversation_id:
            peer.conversation_ids.add(conversation_id)
        self._peers.add(peer)
        return peer

    def disconnect(self, peer: CsPeer) -> None:
        self._peers.discard(peer)

    def watch(self, peer: CsPeer, conversation_id: str) -> None:
        peer.conversation_ids = {conversation_id} if conversation_id else set()

    async def _safe_send(self, peer: CsPeer, payload: dict[str, Any]) -> None:
        if peer.ws.client_state != WebSocketState.CONNECTED:
            self.disconnect(peer)
            return
        try:
            await peer.ws.send_json(payload)
        except Exception:
            logger.debug("cs ws send failed, drop peer", exc_info=True)
            self.disconnect(peer)

    async def _broadcast_message(
        self,
        cid: str,
        conv_payload: dict[str, Any],
        msg_admin: dict[str, Any],
        msg_user: dict[str, Any],
    ) -> None:
        for peer in list(self._peers):
            try:
                if peer.role == "user":
                    if cid not in peer.conversation_ids:
                        continue
                    await self._safe_send(
                        peer,
                        {
                            "type": "message",
                            "item": msg_user,
                            "conversation": conv_payload,
                        },
                    )
                else:
                    if cid in peer.conversation_ids:
                        await self._safe_send(
                            peer,
                            {
                                "type": "message",
                                "item": msg_admin,
                                "conversation": conv_payload,
                            },
                        )
                    await self._safe_send(
                        peer,
                        {"type": "conversation", "item": conv_payload},
                    )
            except Exception:
                self.disconnect(peer)

    async def _broadcast_conversation(self, conv_payload: dict[str, Any]) -> None:
        for peer in list(self._peers):
            if peer.role == "admin":
                await self._safe_send(peer, {"type": "conversation", "item": conv_payload})

    def publish_message(self, conv: CsConversation, msg: CsMessage) -> None:
        if not self._loop:
            logger.warning("cs hub publish_message skipped: loop not bound")
            return
        try:
            cid = conv.id
            conv_payload = cs_conversation_out(conv)
            msg_admin = cs_message_out(msg, for_admin=True)
            msg_user = cs_message_out(msg, for_admin=False)
        except Exception:
            logger.exception("cs hub serialize failed")
            return
        try:
            asyncio.run_coroutine_threadsafe(
                self._broadcast_message(cid, conv_payload, msg_admin, msg_user),
                self._loop,
            )
        except Exception:
            logger.exception("cs hub publish_message failed")

    def publish_conversation(self, conv: CsConversation) -> None:
        if not self._loop:
            logger.warning("cs hub publish_conversation skipped: loop not bound")
            return
        try:
            payload = cs_conversation_out(conv)
        except Exception:
            logger.exception("cs hub serialize conversation failed")
            return
        try:
            asyncio.run_coroutine_threadsafe(self._broadcast_conversation(payload), self._loop)
        except Exception:
            logger.exception("cs hub publish_conversation failed")


cs_hub = CsHub()


async def ws_receive_loop(peer: CsPeer) -> None:
    """保持连接：服务端定时 ping + 接收客户端 ping/watch。"""

    async def _server_ping() -> None:
        while True:
            await asyncio.sleep(20)
            if peer.ws.client_state != WebSocketState.CONNECTED:
                return
            try:
                await peer.ws.send_json({"type": "ping"})
            except Exception:
                return

    ping_task = asyncio.create_task(_server_ping())
    try:
        while True:
            message = await peer.ws.receive()
            mtype = message.get("type")
            if mtype == "websocket.disconnect":
                break
            if mtype != "websocket.receive":
                continue
            text = message.get("text")
            if not text:
                continue
            try:
                data = json.loads(text)
            except Exception:
                continue
            if not isinstance(data, dict):
                continue
            typ = str(data.get("type") or "")
            if typ == "ping":
                await peer.ws.send_json({"type": "pong"})
            elif typ == "watch" and peer.role == "admin":
                cid = str(data.get("conversationId") or data.get("conversation_id") or "").strip()
                cs_hub.watch(peer, cid)
                await peer.ws.send_json({"type": "watched", "conversationId": cid})
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.info("cs ws loop ended", exc_info=True)
    finally:
        ping_task.cancel()
        try:
            await ping_task
        except Exception:
            pass
        cs_hub.disconnect(peer)
