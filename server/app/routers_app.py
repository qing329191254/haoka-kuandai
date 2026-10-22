from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketException, status
from jwt import InvalidTokenError
from sqlalchemy.orm import Session

from app.config import settings
from app.deposit import quote_deposit
from app.db import SessionLocal, get_db
from app.deps import app_user_of, require_portal
from app.integrations import SmsRateLimit, esign_provider, pay_provider, sms_provider
from app.sms_aliyun import SmsSendError
from app.cs_chat import (
    AGENT_DISPLAY_NAME,
    APP_HISTORY_LIMIT,
    add_message,
    cs_conversation_out,
    cs_message_out,
    get_or_create_conversation,
    list_messages,
    mark_read_for_user,
    match_quick_reply,
)
from app.cs_hub import cs_hub, ws_receive_loop
from app.models import Agent, AgentApplication, AppUser, Feedback, Merchant, Order, Product
from app.schemas import (
    AppLoginIn,
    AppProfilePatch,
    AppRegisterIn,
    AppResetIn,
    ContractSignIn,
    CsMessageIn,
    DepositPayIn,
    FeedbackIn,
    OrderCreateIn,
    SmsIn,
)
from app.security import create_token, decode_token, hash_password, verify_password
from app.serialize import app_user_out, feedback_out, order_out
from app.services import append_log
from app.util import dump_json, load_json, new_id, now_str, order_no

router = APIRouter(prefix="/api/app", tags=["App 代理"])


def _latest_app(db: Session, phone: str) -> AgentApplication | None:
    return (
        db.query(AgentApplication)
        .filter(AgentApplication.phone == phone)
        .order_by(AgentApplication.created_at.desc())
        .first()
    )


def _token_for(user: AppUser) -> dict:
    token = create_token({"sub": user.id, "portal": "app", "phone": user.phone, "agent_id": user.agent_id})
    return {"token": token, "tokenType": "bearer"}


@router.post("/auth/sms")
def send_sms(body: SmsIn):
    if not body.phone.strip():
        raise HTTPException(400, "请输入手机号")
    try:
        sms_provider.send(body.phone)
    except SmsRateLimit:
        raise HTTPException(400, "验证码发送过于频繁，请稍后再试")
    except SmsSendError as exc:
        raise HTTPException(400, str(exc))
    return {"ok": True, "message": "验证码已发送"}


@router.post("/auth/login")
def login(body: AppLoginIn, db: Session = Depends(get_db)):
    user = db.query(AppUser).filter(AppUser.phone == body.phone.strip()).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(400, "手机号或密码错误")
    if user.status != "active":
        raise HTTPException(403, "账号已停用")
    return {**_token_for(user), "user": app_user_out(user, _latest_app(db, user.phone))}


@router.post("/auth/reset-password")
def reset_password(body: AppResetIn, db: Session = Depends(get_db)):
    if not sms_provider.verify(body.phone, body.code):
        raise HTTPException(400, "验证码错误，请重新输入")
    user = db.query(AppUser).filter(AppUser.phone == body.phone.strip()).first()
    if not user:
        raise HTTPException(400, "账号不存在")
    if len(body.password.strip()) < 6:
        raise HTTPException(400, "密码至少 6 位")
    user.password_hash = hash_password(body.password)
    db.commit()
    return {"ok": True, "message": "密码已重置"}


@router.post("/auth/register")
def register(body: AppRegisterIn, db: Session = Depends(get_db)):
    if not sms_provider.verify(body.phone, body.code):
        raise HTTPException(400, "验证码错误，请重新输入")
    phone = body.phone.strip()
    if db.query(AppUser).filter(AppUser.phone == phone).first():
        raise HTTPException(400, "该手机号已注册")
    t = now_str()
    user = AppUser(
        id=new_id("u"),
        phone=phone,
        password_hash=hash_password(body.password),
        nickname=body.contact,
        company_name=body.company_name,
        created_at=t,
    )
    quoted = quote_deposit(
        db,
        province=body.province,
        city=body.city,
        scale=body.scale,
    )
    app = AgentApplication(
        id=new_id("ap"),
        phone=phone,
        contact=body.contact,
        name=body.company_name,
        province=body.province,
        city=body.city,
        district=body.district,
        address=body.address,
        wechat=body.wechat,
        backup_phone=body.backup_phone,
        id_no=body.id_no,
        license_name=body.license_name,
        remark=body.remark,
        status="pending",
        created_at=t,
        deposit_amount=quoted["amount"],
        scale=quoted["scale"],
    )
    db.add_all([user, app])
    db.commit()
    return {**_token_for(user), "user": app_user_out(user, app)}


@router.get("/me")
def me(payload: dict = Depends(require_portal("app")), db: Session = Depends(get_db)):
    user = app_user_of(db, payload)
    return app_user_out(user, _latest_app(db, user.phone))


@router.put("/me")
def update_me(
    body: AppProfilePatch,
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    for k in ("nickname", "email", "gender", "avatar_id", "company_name"):
        v = getattr(body, k)
        if v is not None:
            setattr(user, k, v)
    db.commit()
    return app_user_out(user, _latest_app(db, user.phone))


@router.post("/me/contract")
def sign_contract(
    body: ContractSignIn,
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    app = _latest_app(db, user.phone)
    if not app:
        raise HTTPException(400, "请先提交入驻申请")
    result = esign_provider.sign_contract(body.signer_name or app.contact)
    app.contract_signed = True
    app.contract_signed_at = result["signedAt"]
    app.contract_no = result["contractNo"]
    app.signer_name = result["signerName"]
    db.commit()
    return app_user_out(user, app)


@router.post("/me/deposit")
def pay_deposit(
    body: DepositPayIn = DepositPayIn(),
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    app = _latest_app(db, user.phone)
    if not app:
        raise HTTPException(400, "请先提交入驻申请")
    if not app.contract_signed:
        raise HTTPException(400, "请先签署合作协议")
    if app.deposit_paid:
        return {"user": app_user_out(user, app), "payment": {"paid": True, "channel": app.deposit_channel or "alipay"}}

    channel = body.channel or "alipay"
    out_trade_no = new_id("DEP")
    try:
        result = pay_provider.create_deposit(
            app.deposit_amount,
            channel=channel,
            out_trade_no=out_trade_no,
            subject=f"{settings.app_name}入驻保证金",
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    except Exception as e:
        raise HTTPException(502, f"发起支付失败：{e}") from e

    app.deposit_out_trade_no = result.get("outTradeNo") or out_trade_no
    app.deposit_channel = result.get("channel") or channel
    if result.get("paid"):
        app.deposit_paid = True
        app.deposit_paid_at = result.get("paidAt") or now_str()
        app.deposit_trade_no = result.get("tradeNo") or app.deposit_out_trade_no
    db.commit()
    return {"user": app_user_out(user, app), "payment": result}


@router.get("/orders")
def my_orders(
    keyword: str = "",
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    app_user_of(db, payload)
    q = db.query(Order).filter(Order.created_by_user_id == payload["sub"])
    rows = q.order_by(Order.created_at.desc()).all()
    items = [order_out(o) for o in rows]
    if keyword.strip():
        k = keyword.strip().lower()
        items = [o for o in items if k in json_hay(o)]
    return {"items": items, "total": len(items)}


def json_hay(o: dict) -> str:
    return " ".join(str(v or "") for v in o.values()).lower()


@router.get("/orders/{oid}")
def order_detail(oid: str, payload: dict = Depends(require_portal("app")), db: Session = Depends(get_db)):
    user = app_user_of(db, payload)
    o = db.get(Order, oid)
    if not o or o.created_by_user_id != user.id:
        raise HTTPException(404, "订单不存在")
    return order_out(o)


@router.post("/orders")
def create_order(
    body: OrderCreateIn,
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    app = _latest_app(db, user.phone)
    if not user or app is None or app.status != "approved":
        raise HTTPException(403, "入驻审核通过后方可下单")
    product = db.get(Product, body.product_id) if body.product_id else None
    if body.product_id and (not product or product.status != "active"):
        raise HTTPException(400, "套餐不存在或已下架，请刷新后重试")
    if product and product.biz_type != body.biz_type:
        raise HTTPException(400, "套餐与业务类型不匹配")
    if body.biz_type != "haoka" and not (body.assigned_merchant_id or "").strip():
        raise HTTPException(400, "请选择办理商家")
    merchant = db.get(Merchant, body.assigned_merchant_id) if body.assigned_merchant_id else None
    if body.assigned_merchant_id:
        if not merchant or merchant.status != "active":
            raise HTTPException(400, "所选商家不存在或已停用")
        if body.biz_type not in load_json(merchant.biz_types):
            raise HTTPException(400, "所选商家不承接该业务")
        if body.province and merchant.province != body.province:
            raise HTTPException(400, "所选商家不在办理省份")
        if body.city and merchant.city != body.city:
            raise HTTPException(400, "所选商家不在办理城市")
    t = now_str()
    region = " ".join(x for x in (body.province, body.city, body.district) if x)
    o = Order(
        id=new_id("o"),
        order_no=order_no(body.biz_type),
        biz_type=body.biz_type,
        status="listed",
        customer_name=body.customer_name,
        customer_phone=body.customer_phone,
        customer_id_no=body.customer_id_no,
        address=body.address,
        product_id=body.product_id,
        product_name=product.name if product else body.product_name,
        carrier=product.carrier if product else body.carrier,
        need_new_card=body.biz_type in {"haoka", "broadband_new_card"},
        assigned_merchant_id=body.assigned_merchant_id or None,
        assigned_merchant_name="",
        created_at=t,
        updated_at=t,
        remark=body.remark,
        source="app",
        region=region,
        province=body.province,
        city=body.city,
        district=body.district,
        commission=product.commission if product else 0,
        stock_type_id=(product.stock_type_id or "") if product else body.stock_type_id,
        stock_type_name=body.stock_type_name,
        order_intent=body.order_intent,
        phone_brand=body.phone_brand,
        price_range=body.price_range,
        wifi_device_type=body.wifi_device_type,
        wifi_biz_mode=body.wifi_biz_mode,
        agent_id=user.agent_id,
        created_by_user_id=user.id,
        logs=dump_json([]),
    )
    if merchant:
        o.assigned_merchant_name = merchant.mp_display_name or merchant.name
    append_log(o, user.nickname or user.phone, "提交订单", "app")
    if user.agent_id:
        agent = db.get(Agent, user.agent_id)
        if agent:
            agent.order_count = (agent.order_count or 0) + 1
    db.add(o)
    db.commit()
    db.refresh(o)
    return order_out(o)


@router.post("/feedback")
def feedback(
    body: FeedbackIn,
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    content = (body.content or "").strip()
    if len(content) < 5:
        raise HTTPException(400, "请至少填写 5 个字")
    row = Feedback(
        id=new_id("fb"),
        type=(body.type or "其他").strip() or "其他",
        content=content,
        contact=(body.contact or "").strip() or (user.phone if user else ""),
        user_name=(user.nickname if user else "") or "",
        user_id=user.id if user else "",
        channel="app_feedback",
        created_at=now_str(),
        status="pending",
        reply="",
        admin_note="",
        handled_at="",
        handled_by="",
    )
    db.add(row)
    db.commit()
    return {"ok": True, "id": row.id, "item": feedback_out(row)}


@router.get("/feedbacks")
def my_feedbacks(
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    rows = (
        db.query(Feedback)
        .filter(Feedback.user_id == user.id)
        .order_by(Feedback.created_at.desc())
        .limit(50)
        .all()
    )
    return {"items": [feedback_out(f) for f in rows], "total": len(rows)}


@router.get("/cs/session")
def cs_session(
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    """获取或创建当前用户的在线客服会话，并返回历史消息。"""
    user = app_user_of(db, payload)
    conv = get_or_create_conversation(db, user)
    mark_read_for_user(db, conv)
    msgs = list_messages(db, conv.id, limit=APP_HISTORY_LIMIT)
    db.commit()
    return {
        "conversation": cs_conversation_out(conv),
        "messages": [cs_message_out(m, for_admin=False) for m in msgs],
        "agentDisplayName": "派客邦客服",
    }


@router.get("/cs/messages")
def cs_poll_messages(
    after: str = "",
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    """兼容旧客户端轮询；新版走 WebSocket。"""
    user = app_user_of(db, payload)
    conv = get_or_create_conversation(db, user)
    msgs = list_messages(db, conv.id, after_id=(after or "").strip(), limit=100)
    if msgs:
        mark_read_for_user(db, conv)
        db.commit()
    return {
        "conversationId": conv.id,
        "items": [cs_message_out(m, for_admin=False) for m in msgs],
    }


@router.post("/cs/messages")
def cs_send_message(
    body: CsMessageIn,
    payload: dict = Depends(require_portal("app")),
    db: Session = Depends(get_db),
):
    user = app_user_of(db, payload)
    msg_type = (body.msg_type or "text").strip() or "text"
    content = (body.content or "").strip()
    if msg_type == "image":
        if not content:
            raise HTTPException(400, "图片地址不能为空")
    else:
        msg_type = "text"
        if not content:
            raise HTTPException(400, "请输入内容")
        if len(content) > 2000:
            raise HTTPException(400, "单条消息过长")
    conv = get_or_create_conversation(db, user)
    msg = add_message(db, conv, sender_type="user", content=content, msg_type=msg_type)
    auto_msg = None
    if msg_type == "text":
        auto_text = match_quick_reply(db, content)
        if auto_text:
            auto_msg = add_message(
                db,
                conv,
                sender_type="system",
                content=auto_text,
                msg_type="text",
                agent_name=AGENT_DISPLAY_NAME,
            )
    mark_read_for_user(db, conv)
    db.commit()
    db.refresh(msg)
    if auto_msg is not None:
        db.refresh(auto_msg)
    cs_hub.publish_message(conv, msg)
    auto_item = None
    if auto_msg is not None:
        cs_hub.publish_message(conv, auto_msg)
        auto_item = cs_message_out(auto_msg, for_admin=False)
    return {
        "ok": True,
        "item": cs_message_out(msg, for_admin=False),
        "autoReply": auto_item,
    }


@router.websocket("/cs/ws")
async def cs_app_ws(websocket: WebSocket, token: str = ""):
    """App 客服实时通道。连接：/api/app/cs/ws?token=JWT"""
    raw = (token or "").strip()
    if not raw:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="missing token")
    try:
        payload = decode_token(raw)
    except InvalidTokenError:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="invalid token")
    if payload.get("portal") != "app":
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="forbidden")

    db = SessionLocal()
    peer = None
    try:
        user = app_user_of(db, payload)
        conv = get_or_create_conversation(db, user)
        mark_read_for_user(db, conv)
        db.commit()
        peer = await cs_hub.connect(websocket, role="user", conversation_id=conv.id)
        await websocket.send_json(
            {
                "type": "ready",
                "conversationId": conv.id,
                "agentDisplayName": AGENT_DISPLAY_NAME,
            }
        )
        await ws_receive_loop(peer)
    finally:
        if peer is not None:
            cs_hub.disconnect(peer)
        db.close()
