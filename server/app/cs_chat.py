"""在线客服：会话/消息公共逻辑（App 对外品牌名写死，后台记真实坐席）。"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import AppUser, CsConversation, CsMessage, ServiceConfig
from app.util import new_id, now_str

# 用户端气泡昵称（不区分具体客服）
AGENT_DISPLAY_NAME = "派客邦客服"
WELCOME_FALLBACK = (
    "您好，欢迎咨询派客邦客服。请直接描述您的问题，我们会尽快回复。"
    "也可先点下方快捷入口。"
)


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
    after_id: str = "",
    limit: int = 100,
) -> list[CsMessage]:
    q = db.query(CsMessage).filter(CsMessage.conversation_id == conversation_id)
    if after_id:
        anchor = db.get(CsMessage, after_id)
        if anchor and anchor.conversation_id == conversation_id:
            q = q.filter(
                (CsMessage.created_at > anchor.created_at)
                | ((CsMessage.created_at == anchor.created_at) & (CsMessage.id > anchor.id))
            )
    return q.order_by(CsMessage.created_at.asc(), CsMessage.id.asc()).limit(limit).all()


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
