"""在线客服 WebSocket 连接中心：按会话房间广播，管理端另有大厅收列表更新。"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect, WebSocketState

from app.config import ROOT
from app.cs_chat import cs_conversation_out, cs_message_out
from app.models import CsConversation, CsMessage

logger = logging.getLogger(__name__)
_DBG = ROOT / "cs_ws_debug.log"

Role = Literal["user", "admin"]


def _dbg(msg: str) -> None:
    try:
        with _DBG.open("a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception:
        pass


@dataclass
class CsPeer:
    ws: WebSocket
    role: Role
    conversation_ids: set[str] = field(default_factory=set)
    _send_lock: asyncio.Lock | None = field(default=None, repr=False)

    def lock(self) -> asyncio.Lock:
        if self._send_lock is None:
            self._send_lock = asyncio.Lock()
        return self._send_lock


class CsHub:
    def __init__(self) -> None:
        # 必须用 list：CsPeer 含 WebSocket/Lock，不可哈希，set.add 会直接 TypeError
        # （表现为 101 成功但永远发不出 ready——根因就在这）
        self._peers: list[CsPeer] = []
        self._sse_queues: list[asyncio.Queue[dict[str, Any]]] = []
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def subscribe_sse(self) -> asyncio.Queue[dict[str, Any]]:
        q: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=200)
        self._sse_queues.append(q)
        return q

    def unsubscribe_sse(self, q: asyncio.Queue[dict[str, Any]]) -> None:
        try:
            self._sse_queues.remove(q)
        except ValueError:
            pass

    def _fanout_sse(self, payload: dict[str, Any]) -> None:
        dead: list[asyncio.Queue[dict[str, Any]]] = []
        for q in self._sse_queues:
            try:
                q.put_nowait(payload)
            except asyncio.QueueFull:
                dead.append(q)
        for q in dead:
            self.unsubscribe_sse(q)

    async def connect(self, ws: WebSocket, *, role: Role, conversation_id: str = "") -> CsPeer:
        await ws.accept()
        peer = CsPeer(ws=ws, role=role)
        if conversation_id:
            peer.conversation_ids.add(conversation_id)
        self._peers.append(peer)
        _dbg(f"accept role={role} peers={len(self._peers)}")
        return peer

    def disconnect(self, peer: CsPeer) -> None:
        self._peers = [p for p in self._peers if p is not peer]

    def watch(self, peer: CsPeer, conversation_id: str) -> None:
        peer.conversation_ids = {conversation_id} if conversation_id else set()

    async def send(self, peer: CsPeer, payload: dict[str, Any]) -> bool:
        try:
            text = json.dumps(payload, ensure_ascii=True, separators=(",", ":"))
            async with peer.lock():
                await peer.ws.send_text(text)
            return True
        except Exception as e:
            _dbg(f"send fail role={peer.role} type={payload.get('type')} err={e!r}")
            logger.info("cs ws send failed role=%s", peer.role, exc_info=True)
            self.disconnect(peer)
            return False

    async def _safe_send(self, peer: CsPeer, payload: dict[str, Any]) -> None:
        await self.send(peer, payload)

    async def _broadcast_message(
        self,
        cid: str,
        conv_payload: dict[str, Any],
        msg_admin: dict[str, Any],
        msg_user: dict[str, Any],
    ) -> None:
        # 管理端 SSE（HTTPS 长连接，避开现网 WSS 下行丢帧）
        self._fanout_sse(
            {"type": "message", "item": msg_admin, "conversation": conv_payload},
        )
        self._fanout_sse({"type": "conversation", "item": conv_payload})
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
        self._fanout_sse({"type": "conversation", "item": conv_payload})
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


async def ws_receive_loop(peer: CsPeer, *, ready: dict[str, Any] | None = None) -> None:
    """先无锁直接发 ready，再进入收发循环。"""
    payload: dict[str, Any] = {"type": "ready"}
    if ready:
        payload.update(ready)
    try:
        # 首包不用锁，尽量在握手后立刻下发，避免客户端空消息重连
        await peer.ws.send_text(json.dumps(payload, ensure_ascii=True, separators=(",", ":")))
        _dbg(f"ready sent role={peer.role}")
    except Exception as e:
        _dbg(f"ready send fail role={peer.role} err={e!r}")
        cs_hub.disconnect(peer)
        return

    async def _server_ping() -> None:
        while True:
            await asyncio.sleep(25)
            if peer.ws.client_state != WebSocketState.CONNECTED:
                return
            if not await cs_hub.send(peer, {"type": "ping"}):
                return

    ping_task = asyncio.create_task(_server_ping())
    try:
        while True:
            text = await peer.ws.receive_text()
            try:
                data = json.loads(text)
            except Exception:
                continue
            if not isinstance(data, dict):
                continue
            typ = str(data.get("type") or "")
            if typ == "ping":
                await cs_hub.send(peer, {"type": "pong"})
            elif typ == "pong":
                continue
            elif typ == "watch" and peer.role == "admin":
                cid = str(data.get("conversationId") or data.get("conversation_id") or "").strip()
                cs_hub.watch(peer, cid)
                await cs_hub.send(peer, {"type": "watched", "conversationId": cid})
    except WebSocketDisconnect as e:
        _dbg(f"disconnect role={peer.role} code={getattr(e, 'code', '')}")
    except Exception as e:
        _dbg(f"loop err role={peer.role} err={e!r}")
        logger.info("cs ws loop ended role=%s", peer.role, exc_info=True)
    finally:
        ping_task.cancel()
        try:
            await ping_task
        except Exception:
            pass
        cs_hub.disconnect(peer)
