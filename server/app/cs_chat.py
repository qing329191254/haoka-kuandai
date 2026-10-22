"""在线客服：会话/消息公共逻辑（App 对外品牌名写死，后台记真实坐席）。"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models import AppUser, CsConversation, CsMessage, ServiceConfig
from app.util import load_json, new_id, now_str

logger = logging.getLogger(__name__)

# 用户端气泡昵称（不区分具体客服）
AGENT_DISPLAY_NAME = "派客邦客服"
WELCOME_FALLBACK = (
    "您好，欢迎咨询派客邦客服。请直接描述您的问题，我们会尽快回复。"
    "也可先点下方快捷问题。"
)

# 生命周期：客服可手动结束；静默超时自动结束；历史只保留窗口内数据
APP_HISTORY_LIMIT = 100
ADMIN_HISTORY_LIMIT = 100
IDLE_CLOSE_HOURS = 48
MESSAGE_RETENTION_DAYS = 90
LIST_RETENTION_DAYS = 90


def _cutoff_str(*, hours: int = 0, days: int = 0) -> str:
    return (datetime.now() - timedelta(hours=hours, days=days)).strftime("%Y-%m-%d %H:%M:%S")


def cs_message_out(m: CsMessage, *, for_admin: bool = False) -> dict:
    display_name = ""
    if m.sender_type == "user":
        display_name = "我"
    elif m.sender_type in {"agent", "system"}:
        display_name = AGENT_DISPLAY_NAME if not for_admin else (m.agent_name or AGENT_DISPLAY_NAME)
    return {
        "id": m.id,
        "conversationId": m.conversation_id,
        "senderType": m.sender_type,
        "agentId": m.agent_id or "",
        "agentName": m.agent_name or "",
        "displayName": display_name,
        "msgType": m.msg_type or "text",
        "content": m.content or "",
        "createdAt": m.created_at,
    }


def cs_conversation_out(c: CsConversation) -> dict:
    return {
        "id": c.id,
        "userId": c.user_id,
        "userName": c.user_name or "",
        "userPhone": c.user_phone or "",
        "status": c.status,
        "lastMessage": c.last_message or "",
        "lastMessageAt": c.last_message_at or "",
        "userUnread": int(c.user_unread or 0),
        "agentUnread": int(c.agent_unread or 0),
        "createdAt": c.created_at,
        "updatedAt": c.updated_at or c.created_at,
    }


def _preview(content: str, msg_type: str) -> str:
    if msg_type == "image":
        return "[图片]"
    text = (content or "").strip().replace("\n", " ")
    return text[:80] if text else ""


def _welcome_text(db: Session) -> str:
    cfg = db.query(ServiceConfig).first()
    work = (cfg.work_time if cfg else "") or ""
    if work:
        return f"您好，欢迎咨询派客邦客服。人工服务时间：{work}。请直接描述问题，我们会尽快回复。"
    return WELCOME_FALLBACK


def get_open_conversation(db: Session, user_id: str) -> CsConversation | None:
    return (
        db.query(CsConversation)
        .filter(CsConversation.user_id == user_id, CsConversation.status == "open")
        .order_by(CsConversation.updated_at.desc())
        .first()
    )


def get_or_create_conversation(db: Session, user: AppUser) -> CsConversation:
    row = get_open_conversation(db, user.id)
    if row:
        # 同步资料
        row.user_name = user.nickname or row.user_name
        row.user_phone = user.phone or row.user_phone
        return row

    now = now_str()
    row = CsConversation(
        id=new_id("csc"),
        user_id=user.id,
        user_name=user.nickname or "",
        user_phone=user.phone or "",
        status="open",
        last_message="",
        last_message_at=now,
        user_unread=0,
        agent_unread=0,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    db.flush()
    welcome = CsMessage(
        id=new_id("csm"),
        conversation_id=row.id,
        sender_type="system",
        agent_id="",
        agent_name=AGENT_DISPLAY_NAME,
        msg_type="text",
        content=_welcome_text(db),
        created_at=now,
    )
    db.add(welcome)
    row.last_message = _preview(welcome.content, "text")
    row.last_message_at = now
    row.user_unread = 1
    return row


def list_messages(
    db: Session,
    conversation_id: str,
    *,
    limit: int = APP_HISTORY_LIMIT,
) -> list[CsMessage]:
    """取最近 limit 条，按时间正序返回（实时增量走 WebSocket）。"""
    rows = (
        db.query(CsMessage)
        .filter(CsMessage.conversation_id == conversation_id)
        .order_by(CsMessage.created_at.desc(), CsMessage.id.desc())
        .limit(limit)
        .all()
    )
    rows.reverse()
    return rows


def close_idle_conversations(db: Session) -> list[CsConversation]:
    """open 且双方静默超过 IDLE_CLOSE_HOURS → closed。"""
    cutoff = _cutoff_str(hours=IDLE_CLOSE_HOURS)
    now = now_str()
    rows = (
        db.query(CsConversation)
        .filter(CsConversation.status == "open", CsConversation.last_message_at < cutoff)
        .all()
    )
    for conv in rows:
        conv.status = "closed"
        conv.updated_at = now
    if rows:
        logger.info("cs idle-close: %s conversation(s) before %s", len(rows), cutoff)
    return rows


def purge_old_messages(db: Session) -> int:
    """删除超过 MESSAGE_RETENTION_DAYS 的消息；并清理无消息的过期已关闭会话。"""
    msg_cutoff = _cutoff_str(days=MESSAGE_RETENTION_DAYS)
    deleted = (
        db.query(CsMessage)
        .filter(CsMessage.created_at < msg_cutoff)
        .delete(synchronize_session=False)
    )
    # 已关闭且长期无活动、且已无消息的会话一并清掉
    stale = (
        db.query(CsConversation)
        .filter(
            CsConversation.status == "closed",
            CsConversation.last_message_at < msg_cutoff,
        )
        .all()
    )
    removed_conv = 0
    for conv in stale:
        left = (
            db.query(CsMessage)
            .filter(CsMessage.conversation_id == conv.id)
            .limit(1)
            .first()
        )
        if left is None:
            db.delete(conv)
            removed_conv += 1
    if deleted or removed_conv:
        logger.info(
            "cs purge: messages=%s empty_closed_conversations=%s before %s",
            deleted,
            removed_conv,
            msg_cutoff,
        )
    return int(deleted or 0)


def list_conversations_for_admin(db: Session, *, limit: int = 200) -> list[CsConversation]:
    """进行中全部展示；已关闭仅保留 LIST_RETENTION_DAYS 内。"""
    cutoff = _cutoff_str(days=LIST_RETENTION_DAYS)
    return (
        db.query(CsConversation)
        .filter(
            (CsConversation.status == "open")
            | (CsConversation.last_message_at >= cutoff)
        )
        .order_by(CsConversation.last_message_at.desc(), CsConversation.updated_at.desc())
        .limit(limit)
        .all()
    )


def add_message(
    db: Session,
    conv: CsConversation,
    *,
    sender_type: str,
    content: str,
    msg_type: str = "text",
    agent_id: str = "",
    agent_name: str = "",
) -> CsMessage:
    now = now_str()
    msg = CsMessage(
        id=new_id("csm"),
        conversation_id=conv.id,
        sender_type=sender_type,
        agent_id=agent_id or "",
        agent_name=agent_name or "",
        msg_type=msg_type if msg_type in {"text", "image"} else "text",
        content=content,
        created_at=now,
    )
    db.add(msg)
    conv.last_message = _preview(content, msg.msg_type)
    conv.last_message_at = now
    conv.updated_at = now
    if conv.status == "closed":
        conv.status = "open"
    if sender_type == "user":
        conv.agent_unread = int(conv.agent_unread or 0) + 1
    else:
        conv.user_unread = int(conv.user_unread or 0) + 1
    return msg


def mark_read_for_user(db: Session, conv: CsConversation) -> None:
    if conv.user_unread:
        conv.user_unread = 0


def mark_read_for_agent(db: Session, conv: CsConversation) -> None:
    if conv.agent_unread:
        conv.agent_unread = 0


def match_quick_reply(db: Session, content: str) -> str:
    """用户发送文案若完全匹配「快捷问题」标签，返回配置的自动回复。"""
    text = (content or "").strip()
    if not text:
        return ""
    cfg = db.query(ServiceConfig).first()
    if not cfg:
        return ""
    for item in load_json(cfg.quick_replies) or []:
        if not isinstance(item, dict):
            continue
        prompt = str(item.get("prompt") or "").strip()
        reply = str(item.get("reply") or "").strip()
        if prompt and prompt == text and reply:
            return reply
    return ""
