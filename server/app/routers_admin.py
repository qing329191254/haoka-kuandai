from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketException, status
from starlette.websockets import WebSocketDisconnect
from jwt import InvalidTokenError
from sqlalchemy.orm import Session

from app.cs_chat import (
    ADMIN_HISTORY_LIMIT,
    add_message,
    cs_conversation_out,
    cs_message_out,
    list_conversations_for_admin,
    list_messages,
    mark_read_for_agent,
)
from app.cs_hub import cs_hub, ws_receive_loop
from app.db import SessionLocal, get_db
from app.deps import require_perm, require_portal
from app.models import (
    Agent,
    AgentApplication,
    AppUser,
    AppVersionConfig,
    ContentDoc,
    CsConversation,
    Faq,
    Feedback,
    Merchant,
    MerchantApplication,
    Order,
    Product,
    Role,
    ServiceConfig,
    Staff,
    StockBizType,
    StockRecord,
    Technician,
    WarehouseItem,
    DepositRule,
)
from app.schemas import (
    AdminLoginIn,
    AgentIn,
    CsMessageIn,
    FeedbackHandleIn,
    MerchantIn,
    ProductIn,
    RejectIn,
    RemarkIn,
    RoleIn,
    StaffIn,
    StaffUpdateIn,
    StockMoveIn,
    TechIn,
    WarehouseIn,
)
from app.deposit import VALID_SCALES, deposit_rule_out, normalize_scale
from app.security import create_token, decode_token, hash_password, verify_password
from app.serialize import (
    agent_app_out,
    agent_out,
    app_user_admin_out,
    app_version_out,
    doc_out,
    faq_out,
    feedback_out,
    merchant_app_out,
    merchant_out,
    order_out,
    product_out,
    role_out,
    service_out,
    staff_out,
    stock_record_out,
    stock_type_out,
    tech_out,
    warehouse_out,
)
from app.services import append_log, cancel_order
from app.util import dump_json, load_json, new_id, now_str

router = APIRouter(prefix="/api/admin", tags=["运营后台"])


@router.post("/auth/login")
def login(body: AdminLoginIn, db: Session = Depends(get_db)):
    staff = db.query(Staff).filter(Staff.username == body.username.strip()).first()
    if not staff or not verify_password(body.password, staff.password_hash):
        raise HTTPException(400, "用户名或密码错误")
    if staff.status != "active":
        raise HTTPException(403, "账号已停用")
    role = db.get(Role, staff.role_id)
    token = create_token({"sub": staff.id, "portal": "admin", "username": staff.username, "role_id": staff.role_id})
    return {
        "token": token,
        "user": {
            "id": staff.id,
            "username": staff.username,
            "name": staff.name,
            "roleId": staff.role_id,
            "roleName": role.name if role else "",
            "permissions": load_json(role.permissions) if role else [],
        },
    }


@router.get("/me")
def me(payload: dict = Depends(require_portal("admin")), db: Session = Depends(get_db)):
    staff = db.get(Staff, payload.get("sub"))
    if not staff or staff.status != "active":
        raise HTTPException(401, "登录已过期，请重新登录")
    role = db.get(Role, staff.role_id)
    return {
        "id": staff.id,
        "username": staff.username,
        "name": staff.name,
        "roleId": staff.role_id,
        "roleName": role.name if role else "",
        "permissions": load_json(role.permissions) if role else [],
    }


@router.get("/dashboard")
def dashboard(_: dict = Depends(require_perm("dashboard:view")), db: Session = Depends(get_db)):
    all_o = db.query(Order).all()
    techs = db.query(Technician).all()
    merchants = db.query(Merchant).all()
    agents = db.query(Agent).all()
    wh = db.query(WarehouseItem).all()
    rec = db.query(StockRecord).all()
    return {
        "total": len(all_o),
        "pending": sum(1 for o in all_o if o.status == "listed"),
        "processing": sum(1 for o in all_o if o.status not in {"listed", "done", "cancelled", "follow_up", "failed"}),
        "done": sum(1 for o in all_o if o.status == "done"),
        "cancelled": sum(1 for o in all_o if o.status == "cancelled"),
        "followUp": sum(1 for o in all_o if o.status in {"follow_up", "failed"}),
        "haoka": sum(1 for o in all_o if o.biz_type == "haoka"),
        "mpTodo": sum(1 for t in techs if t.status == "active"),
        "merchantActive": sum(1 for m in merchants if m.status == "active"),
        "agentActive": sum(1 for a in agents if a.status == "active"),
        "warehouseSku": len(wh),
        "warehouseQty": sum(w.stock for w in wh),
        "stockLow": sum(1 for w in wh if w.stock <= w.safety_stock),
        "stockIn": sum(1 for r in rec if r.type == "in"),
        "stockOut": sum(1 for r in rec if r.type == "out"),
    }


@router.get("/orders")
def orders(
    group: str = "all",
    keyword: str = "",
    _: dict = Depends(require_perm("orders:view")),
    db: Session = Depends(get_db),
):
    rows = db.query(Order).order_by(Order.created_at.desc()).all()
    items = [order_out(o) for o in rows]
    if group == "pending":
        items = [o for o in items if o["status"] == "listed"]
    elif group == "done":
        items = [o for o in items if o["status"] == "done"]
    elif group == "follow_up":
        items = [o for o in items if o["status"] in {"follow_up", "failed"}]
    elif group == "cancelled":
        items = [o for o in items if o["status"] == "cancelled"]
    elif group == "processing":
        items = [o for o in items if o["status"] not in {"listed", "done", "follow_up", "failed", "cancelled"}]
    if keyword.strip():
        k = keyword.lower()
        items = [o for o in items if k in json.dumps(o, ensure_ascii=False).lower()]
    return {"items": items, "total": len(items)}


@router.get("/orders/{oid}")
def order_one(oid: str, _: dict = Depends(require_perm("orders:view")), db: Session = Depends(get_db)):
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    return order_out(o)


@router.post("/orders/{oid}/cancel")
def admin_cancel(oid: str, body: RemarkIn, payload: dict = Depends(require_perm("orders:edit")), db: Session = Depends(get_db)):
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    cancel_order(o, body.reason or body.remark, "运营人员", "admin")
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/remark")
def admin_remark(oid: str, body: RemarkIn, _: dict = Depends(require_perm("orders:edit")), db: Session = Depends(get_db)):
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    o.remark = body.remark
    append_log(o, "运营人员", f"备注：{body.remark}", "admin")
    db.commit()
    return order_out(o)


@router.get("/products")
def products(_: dict = Depends(require_perm("products:view")), db: Session = Depends(get_db)):
    rows = db.query(Product).all()
    return {"items": [product_out(p) for p in rows], "total": len(rows)}


@router.post("/products")
def create_product(body: ProductIn, _: dict = Depends(require_perm("products:edit")), db: Session = Depends(get_db)):
    p = Product(id=new_id("p"), **body.model_dump())
    db.add(p)
    db.commit()
    return product_out(p)


@router.put("/products/{pid}")
def update_product(pid: str, body: ProductIn, _: dict = Depends(require_perm("products:edit")), db: Session = Depends(get_db)):
    p = db.get(Product, pid)
    if not p:
        raise HTTPException(404, "商品不存在")
    for k, v in body.model_dump().items():
        setattr(p, k, v)
    db.commit()
    return product_out(p)


@router.get("/stock-types")
def stock_types(_: dict = Depends(require_perm("products:view")), db: Session = Depends(get_db)):
    rows = db.query(StockBizType).order_by(StockBizType.sort).all()
    return {"items": [stock_type_out(t) for t in rows], "total": len(rows)}


@router.get("/agents")
def agents(_: dict = Depends(require_perm("agents:view")), db: Session = Depends(get_db)):
    rows = db.query(Agent).all()
    return {"items": [agent_out(a) for a in rows], "total": len(rows)}


@router.post("/agents")
def create_agent(body: AgentIn, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    if db.query(Agent).filter(Agent.phone == body.phone.strip()).first():
        raise HTTPException(400, "该手机号已存在代理商档案")
    data = body.model_dump()
    data["phone"] = body.phone.strip()
    a = Agent(id=new_id("a"), joined_at=now_str(), order_count=0, license_name="", **data)
    db.add(a)
    db.commit()
    return agent_out(a)


@router.put("/agents/{aid}")
def update_agent(aid: str, body: AgentIn, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    a = db.get(Agent, aid)
    if not a:
        raise HTTPException(404, "代理不存在")
    for k, v in body.model_dump().items():
        setattr(a, k, v)
    db.commit()
    return agent_out(a)


@router.get("/agent-applications")
def agent_apps(_: dict = Depends(require_perm("agents:view")), db: Session = Depends(get_db)):
    rows = db.query(AgentApplication).order_by(AgentApplication.created_at.desc()).all()
    return {"items": [agent_app_out(a) for a in rows], "total": len(rows)}


@router.post("/agent-applications/{aid}/approve")
def approve_agent(aid: str, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    app = db.get(AgentApplication, aid)
    if not app or app.status != "pending":
        raise HTTPException(400, "申请不存在或已处理")
    if not app.contract_signed:
        raise HTTPException(400, "代理尚未完成电子签，无法通过")
    if not app.deposit_paid:
        raise HTTPException(400, "代理尚未缴纳押金，无法通过")
    agent = Agent(
        id=new_id("a"),
        name=app.name,
        phone=app.phone,
        contact=app.contact,
        province=app.province,
        city=app.city,
        district=app.district,
        address=app.address,
        wechat=app.wechat,
        backup_phone=app.backup_phone,
        id_no=app.id_no,
        license_name=app.license_name,
        joined_at=now_str(),
        status="active",
        remark=app.remark,
    )
    db.add(agent)
    app.status = "approved"
    app.reviewed_at = now_str()
    app.agent_id = agent.id
    user = db.query(AppUser).filter(AppUser.phone == app.phone).first()
    if user:
        user.agent_id = agent.id
    db.commit()
    return agent_app_out(app)


@router.post("/agent-applications/{aid}/reject")
def reject_agent(aid: str, body: RejectIn, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    app = db.get(AgentApplication, aid)
    if not app or app.status != "pending":
        raise HTTPException(400, "申请不存在或已处理")
    if not body.reason.strip():
        raise HTTPException(400, "请填写驳回原因")
    app.status = "rejected"
    app.reject_reason = body.reason.strip()
    app.reviewed_at = now_str()
    db.commit()
    return agent_app_out(app)


@router.get("/merchants")
def merchants(_: dict = Depends(require_perm("merchants:view")), db: Session = Depends(get_db)):
    rows = db.query(Merchant).all()
    return {"items": [merchant_out(m) for m in rows], "total": len(rows)}


@router.post("/merchants")
def create_merchant(body: MerchantIn, _: dict = Depends(require_perm("merchants:edit")), db: Session = Depends(get_db)):
    data = body.model_dump()
    types = data.pop("biz_types")
    m = Merchant(id=new_id("m"), biz_types=dump_json(types), **data)
    db.add(m)
    db.commit()
    return merchant_out(m)


@router.put("/merchants/{mid}")
def update_merchant(mid: str, body: MerchantIn, _: dict = Depends(require_perm("merchants:edit")), db: Session = Depends(get_db)):
    m = db.get(Merchant, mid)
    if not m:
        raise HTTPException(404, "商家不存在")
    data = body.model_dump()
    m.biz_types = dump_json(data.pop("biz_types"))
    for k, v in data.items():
        setattr(m, k, v)
    db.commit()
    return merchant_out(m)


@router.get("/merchant-applications")
def merchant_apps(_: dict = Depends(require_perm("merchants:view")), db: Session = Depends(get_db)):
    rows = db.query(MerchantApplication).order_by(MerchantApplication.created_at.desc()).all()
    return {"items": [merchant_app_out(a) for a in rows], "total": len(rows)}


@router.post("/merchant-applications/{aid}/approve")
def approve_merchant(aid: str, _: dict = Depends(require_perm("merchants:edit")), db: Session = Depends(get_db)):
    app = db.get(MerchantApplication, aid)
    if not app or app.status != "pending":
        raise HTTPException(400, "申请不存在或已处理")
    m = Merchant(
        id=new_id("m"),
        name=app.name,
        phone=app.phone,
        login_phone=app.phone,
        province=app.province,
        city=app.city,
        district=app.district,
        address=app.address,
        status="active",
        biz_types=app.biz_types,
        contact=app.contact,
        mp_display_name=app.name,
    )
    db.add(m)
    app.status = "approved"
    app.reviewed_at = now_str()
    app.merchant_id = m.id
    db.commit()
    return merchant_app_out(app)


@router.post("/merchant-applications/{aid}/reject")
def reject_merchant(aid: str, body: RejectIn, _: dict = Depends(require_perm("merchants:edit")), db: Session = Depends(get_db)):
    app = db.get(MerchantApplication, aid)
    if not app or app.status != "pending":
        raise HTTPException(400, "申请不存在或已处理")
    app.status = "rejected"
    app.reject_reason = body.reason.strip()
    app.reviewed_at = now_str()
    db.commit()
    return merchant_app_out(app)


@router.get("/technicians")
def technicians(_: dict = Depends(require_perm("technicians:view")), db: Session = Depends(get_db)):
    rows = db.query(Technician).all()
    return {"items": [tech_out(t) for t in rows], "total": len(rows)}


@router.post("/technicians")
def create_tech(body: TechIn, _: dict = Depends(require_perm("technicians:edit")), db: Session = Depends(get_db)):
    t = Technician(
        id=new_id("t"),
        name=body.name,
        phone=body.phone.strip(),
        province=body.province,
        city=body.city,
        district=body.district,
        status=body.status,
        merchant_id=body.merchant_id,
        merchant_name=body.merchant_name,
        skills=dump_json(body.skills),
    )
    db.add(t)
    db.commit()
    return tech_out(t)


@router.put("/technicians/{tid}")
def update_tech(tid: str, body: TechIn, _: dict = Depends(require_perm("technicians:edit")), db: Session = Depends(get_db)):
    t = db.get(Technician, tid)
    if not t:
        raise HTTPException(404, "师傅不存在")
    t.name = body.name
    t.phone = body.phone.strip()
    t.province = body.province or t.province
    t.city = body.city or t.city
    t.district = body.district or t.district
    t.status = body.status
    t.skills = dump_json(body.skills)
    if body.merchant_id:
        t.merchant_id = body.merchant_id
        t.merchant_name = body.merchant_name or t.merchant_name
    db.commit()
    return tech_out(t)


@router.delete("/technicians/{tid}")
def delete_tech(tid: str, _: dict = Depends(require_perm("technicians:edit")), db: Session = Depends(get_db)):
    t = db.get(Technician, tid)
    if not t:
        raise HTTPException(404, "师傅不存在")
    db.delete(t)
    db.commit()
    return {"ok": True}


@router.get("/users")
def users(_: dict = Depends(require_perm("users:view")), db: Session = Depends(get_db)):
    rows = db.query(AppUser).all()
    items = []
    for u in rows:
        n = db.query(Order).filter(Order.created_by_user_id == u.id).count()
        items.append(app_user_admin_out(u, n))
    return {"items": items, "total": len(items)}


@router.post("/users/{uid}/toggle")
def toggle_user(uid: str, _: dict = Depends(require_perm("users:edit")), db: Session = Depends(get_db)):
    u = db.get(AppUser, uid)
    if not u:
        raise HTTPException(404, "用户不存在")
    u.status = "disabled" if u.status == "active" else "active"
    db.commit()
    return app_user_admin_out(u)


@router.get("/feedbacks")
def feedbacks(_: dict = Depends(require_perm("feedback:view")), db: Session = Depends(get_db)):
    rows = db.query(Feedback).order_by(Feedback.created_at.desc()).all()
    return {"items": [feedback_out(f) for f in rows], "total": len(rows)}


@router.post("/feedbacks/{fid}/handle")
def handle_fb(
    fid: str,
    body: FeedbackHandleIn = FeedbackHandleIn(),
    payload: dict = Depends(require_perm("feedback:edit")),
    db: Session = Depends(get_db),
):
    f = db.get(Feedback, fid)
    if not f:
        raise HTTPException(404, "反馈不存在")
    reply = (body.reply or "").strip()
    note = (body.note or body.admin_note or "").strip()
    if reply:
        f.reply = reply
    if note:
        f.admin_note = note
    staff = payload.get("staff")
    f.status = "handled"
    f.handled_at = now_str()
    f.handled_by = (getattr(staff, "name", None) or getattr(staff, "username", None) or "") if staff else ""
    db.commit()
    return feedback_out(f)


@router.post("/feedbacks/{fid}/reopen")
def reopen_fb(fid: str, _: dict = Depends(require_perm("feedback:edit")), db: Session = Depends(get_db)):
    f = db.get(Feedback, fid)
    if not f:
        raise HTTPException(404, "反馈不存在")
    f.status = "pending"
    f.handled_at = ""
    f.handled_by = ""
    db.commit()
    return feedback_out(f)


@router.get("/cs/conversations")
def cs_conversations(_: dict = Depends(require_perm("feedback:view")), db: Session = Depends(get_db)):
    rows = list_conversations_for_admin(db, limit=200)
    return {"items": [cs_conversation_out(c) for c in rows], "total": len(rows)}


@router.get("/cs/conversations/{cid}")
def cs_conversation_detail(
    cid: str,
    _: dict = Depends(require_perm("feedback:view")),
    db: Session = Depends(get_db),
):
    conv = db.get(CsConversation, cid)
    if not conv:
        raise HTTPException(404, "会话不存在")
    mark_read_for_agent(db, conv)
    msgs = list_messages(db, conv.id, limit=ADMIN_HISTORY_LIMIT)
    db.commit()
    return {
        "conversation": cs_conversation_out(conv),
        "messages": [cs_message_out(m, for_admin=True) for m in msgs],
    }


@router.post("/cs/conversations/{cid}/messages")
def cs_conversation_reply(
    cid: str,
    body: CsMessageIn,
    payload: dict = Depends(require_perm("feedback:edit")),
    db: Session = Depends(get_db),
):
    conv = db.get(CsConversation, cid)
    if not conv:
        raise HTTPException(404, "会话不存在")
    msg_type = (body.msg_type or "text").strip() or "text"
    content = (body.content or "").strip()
    if msg_type == "image":
        if not content:
            raise HTTPException(400, "图片地址不能为空")
    else:
        msg_type = "text"
        if not content:
            raise HTTPException(400, "请输入回复内容")
        if len(content) > 2000:
            raise HTTPException(400, "单条消息过长")
    staff = payload.get("staff")
    agent_id = getattr(staff, "id", "") or ""
    agent_name = (getattr(staff, "name", None) or getattr(staff, "username", None) or "客服") if staff else "客服"
    msg = add_message(
        db,
        conv,
        sender_type="agent",
        content=content,
        msg_type=msg_type,
        agent_id=agent_id,
        agent_name=agent_name,
    )
    mark_read_for_agent(db, conv)
    db.commit()
    db.refresh(msg)
    cs_hub.publish_message(conv, msg)
    return {"ok": True, "item": cs_message_out(msg, for_admin=True)}


@router.post("/cs/conversations/{cid}/close")
def cs_conversation_close(
    cid: str,
    _: dict = Depends(require_perm("feedback:edit")),
    db: Session = Depends(get_db),
):
    conv = db.get(CsConversation, cid)
    if not conv:
        raise HTTPException(404, "会话不存在")
    conv.status = "closed"
    conv.updated_at = now_str()
    db.commit()
    cs_hub.publish_conversation(conv)
    return cs_conversation_out(conv)


@router.websocket("/cs/ws")
async def cs_admin_ws(websocket: WebSocket, token: str = ""):
    """管理端客服实时通道。连接后可发 {"type":"watch","conversationId":"..."}。"""
    raw = (token or "").strip()
    if not raw:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="missing token")
    try:
        payload = decode_token(raw)
    except InvalidTokenError:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="invalid token")
    if payload.get("portal") != "admin":
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="forbidden")

    db = SessionLocal()
    peer = None
    try:
        staff = db.get(Staff, payload.get("sub") or "")
        if not staff or staff.status != "active":
            raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="forbidden")
        role = db.get(Role, staff.role_id)
        perms = json.loads(role.permissions or "[]") if role else []
        if "*" not in perms and "feedback:view" not in perms:
            raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="no permission")
    finally:
        db.close()

    try:
        peer = await cs_hub.connect(websocket, role="admin")
        await websocket.send_json({"type": "ready"})
        await ws_receive_loop(peer)
    except WebSocketDisconnect:
        pass
    except Exception:
        # 避免未捕获异常把连接打成异常关闭，触发浏览器疯狂重连
        pass
    finally:
        if peer is not None:
            cs_hub.disconnect(peer)


@router.get("/faqs")
def faqs(_: dict = Depends(require_perm("service:view")), db: Session = Depends(get_db)):
    rows = db.query(Faq).order_by(Faq.sort).all()
    return {"items": [faq_out(f) for f in rows], "total": len(rows)}


@router.get("/docs")
def docs(_: dict = Depends(require_perm("content:view")), db: Session = Depends(get_db)):
    rows = db.query(ContentDoc).all()
    return {"items": [doc_out(d) for d in rows], "total": len(rows)}


@router.get("/service-config")
def get_service(_: dict = Depends(require_perm("service:view")), db: Session = Depends(get_db)):
    s = db.get(ServiceConfig, 1)
    if not s:
        raise HTTPException(404, "未配置")
    return service_out(s)


@router.put("/service-config")
def put_service(body: dict, _: dict = Depends(require_perm("service:edit")), db: Session = Depends(get_db)):
    s = db.get(ServiceConfig, 1) or ServiceConfig(id=1)
    s.hotline = body.get("hotline", s.hotline)
    s.work_time = body.get("workTime") or body.get("work_time") or s.work_time
    s.quick_replies = dump_json(body.get("quickReplies") or body.get("quick_replies") or [])
    db.merge(s)
    db.commit()
    return service_out(s)


@router.get("/app-version")
def get_app_version(_: dict = Depends(require_perm("service:view")), db: Session = Depends(get_db)):
    v = db.get(AppVersionConfig, 1)
    if not v:
        return {
            "latestVersion": "1.0.0",
            "minSupportedVersion": "1.0.0",
            "forceUpdate": False,
            "title": "发现新版本",
            "releaseNotes": "",
            "androidUrl": "",
            "iosUrl": "",
            "enabled": True,
        }
    return app_version_out(v)


@router.put("/app-version")
def put_app_version(body: dict, _: dict = Depends(require_perm("service:edit")), db: Session = Depends(get_db)):
    v = db.get(AppVersionConfig, 1) or AppVersionConfig(id=1)
    v.latest_version = (body.get("latestVersion") or body.get("latest_version") or v.latest_version or "1.0.0").strip()
    v.min_supported_version = (
        body.get("minSupportedVersion") or body.get("min_supported_version") or v.min_supported_version or "1.0.0"
    ).strip()
    # 强制仅由最低可用版本控制；废弃外链 apk / forceUpdate 开关
    v.force_update = False
    v.android_url = ""
    v.title = (body.get("title") or v.title or "发现新版本").strip()
    v.release_notes = body.get("releaseNotes") or body.get("release_notes") or v.release_notes or ""
    v.ios_url = (body.get("iosUrl") or body.get("ios_url") or v.ios_url or "").strip()
    v.enabled = bool(body.get("enabled", v.enabled if v.enabled is not None else True))
    db.merge(v)
    db.commit()
    return app_version_out(v)


@router.get("/warehouse")
def warehouse(_: dict = Depends(require_perm("warehouse:view")), db: Session = Depends(get_db)):
    rows = db.query(WarehouseItem).all()
    return {"items": [warehouse_out(w) for w in rows], "total": len(rows)}


@router.post("/warehouse")
def create_wh(body: WarehouseIn, _: dict = Depends(require_perm("warehouse:edit")), db: Session = Depends(get_db)):
    if not body.sku.strip():
        raise HTTPException(400, "请填写 SKU")
    if db.query(WarehouseItem).filter(WarehouseItem.sku == body.sku.strip()).first():
        raise HTTPException(400, "SKU 已存在")
    data = body.model_dump()
    data["sku"] = body.sku.strip()
    data["stock"] = 0
    w = WarehouseItem(id=new_id("w"), updated_at=now_str(), **data)
    db.add(w)
    db.commit()
    return warehouse_out(w)


@router.put("/warehouse/{wid}")
def update_wh(wid: str, body: WarehouseIn, _: dict = Depends(require_perm("warehouse:edit")), db: Session = Depends(get_db)):
    w = db.get(WarehouseItem, wid)
    if not w:
        raise HTTPException(404, "仓库条目不存在")
    duplicate = db.query(WarehouseItem).filter(WarehouseItem.sku == body.sku.strip(), WarehouseItem.id != wid).first()
    if duplicate:
        raise HTTPException(400, "SKU 已存在")
    # 库存数量只能通过出入库单调整，编辑档案不能直接改库存。
    for key in ("product_id", "product_name", "sku", "spec", "safety_stock", "location"):
        setattr(w, key, getattr(body, key))
    w.updated_at = now_str()
    db.commit()
    return warehouse_out(w)


@router.get("/stock-records")
def stock_records(_: dict = Depends(require_perm("stock:view")), db: Session = Depends(get_db)):
    rows = db.query(StockRecord).order_by(StockRecord.created_at.desc()).all()
    return {"items": [stock_record_out(r) for r in rows], "total": len(rows)}


@router.post("/stock/{move}")
def stock_move(move: str, body: StockMoveIn, payload: dict = Depends(require_portal("admin")), db: Session = Depends(get_db)):
    if move not in {"in", "out"}:
        raise HTTPException(400, "类型无效")
    perm = "stock:in" if move == "in" else "stock:out"
    staff = db.get(Staff, payload["sub"])
    role = db.get(Role, staff.role_id) if staff else None
    perms = load_json(role.permissions) if role else []
    if "*" not in perms and perm not in perms:
        raise HTTPException(403, "没有权限")
    if body.qty <= 0:
        raise HTTPException(400, "出入库数量必须大于 0")
    w = db.get(WarehouseItem, body.warehouse_id)
    if not w:
        raise HTTPException(404, "仓库条目不存在")
    if move == "out" and w.stock < body.qty:
        raise HTTPException(400, "库存不足")
    w.stock = w.stock + body.qty if move == "in" else w.stock - body.qty
    w.updated_at = now_str()
    rec = StockRecord(
        id=new_id("sr"),
        type=move,
        warehouse_id=w.id,
        product_id=w.product_id,
        product_name=w.product_name,
        sku=w.sku,
        qty=body.qty,
        order_no=body.order_no,
        operator=staff.name if staff else "",
        remark=body.remark,
        created_at=now_str(),
    )
    db.add(rec)
    db.commit()
    return stock_record_out(rec)


@router.get("/staff")
def staff_list(_: dict = Depends(require_perm("accounts:view")), db: Session = Depends(get_db)):
    rows = db.query(Staff).all()
    return {"items": [staff_out(s, db.get(Role, s.role_id)) for s in rows], "total": len(rows)}


@router.post("/staff")
def create_staff(body: StaffIn, _: dict = Depends(require_perm("accounts:edit")), db: Session = Depends(get_db)):
    if db.query(Staff).filter(Staff.username == body.username).first():
        raise HTTPException(400, "用户名已存在")
    if not db.get(Role, body.role_id):
        raise HTTPException(400, "角色不存在")
    s = Staff(
        id=new_id("s"),
        username=body.username,
        password_hash=hash_password(body.password),
        name=body.name,
        role_id=body.role_id,
        status=body.status,
        created_at=now_str(),
    )
    db.add(s)
    db.commit()
    return staff_out(s, db.get(Role, s.role_id))


@router.put("/staff/{sid}")
def update_staff(sid: str, body: StaffUpdateIn, _: dict = Depends(require_perm("accounts:edit")), db: Session = Depends(get_db)):
    s = db.get(Staff, sid)
    if not s:
        raise HTTPException(404, "账号不存在")
    if s.username == "admin" and (body.username != "admin" or body.role_id != s.role_id or body.status != "active"):
        raise HTTPException(400, "超级管理员账号不可改名、停用或更换角色")
    duplicate = db.query(Staff).filter(Staff.username == body.username.strip(), Staff.id != sid).first()
    if duplicate:
        raise HTTPException(400, "用户名已存在")
    if not db.get(Role, body.role_id):
        raise HTTPException(400, "角色不存在")
    s.username = body.username.strip()
    s.name = body.name.strip()
    s.role_id = body.role_id
    s.status = body.status
    if body.password.strip():
        s.password_hash = hash_password(body.password)
    db.commit()
    return staff_out(s, db.get(Role, s.role_id))


@router.delete("/staff/{sid}")
def delete_staff(sid: str, payload: dict = Depends(require_perm("accounts:edit")), db: Session = Depends(get_db)):
    s = db.get(Staff, sid)
    if not s:
        raise HTTPException(404, "账号不存在")
    if s.username == "admin" or s.id == payload.get("sub"):
        raise HTTPException(400, "不能删除超级管理员或当前登录账号")
    db.delete(s)
    db.commit()
    return {"ok": True}


@router.get("/roles")
def roles(_: dict = Depends(require_perm("roles:view")), db: Session = Depends(get_db)):
    rows = db.query(Role).all()
    return {"items": [role_out(r) for r in rows], "total": len(rows)}


@router.post("/roles")
def create_role(body: RoleIn, _: dict = Depends(require_perm("roles:edit")), db: Session = Depends(get_db)):
    if db.query(Role).filter(Role.code == body.code.strip()).first():
        raise HTTPException(400, "角色编码已存在")
    r = Role(id=new_id("r"), name=body.name, code=body.code, builtin=False, permissions=dump_json(body.permissions), remark=body.remark)
    db.add(r)
    db.commit()
    return role_out(r)


@router.put("/roles/{rid}")
def update_role(rid: str, body: RoleIn, _: dict = Depends(require_perm("roles:edit")), db: Session = Depends(get_db)):
    r = db.get(Role, rid)
    if not r:
        raise HTTPException(404, "角色不存在")
    if r.code == "admin":
        raise HTTPException(400, "超级管理员角色不可修改")
    duplicate = db.query(Role).filter(Role.code == body.code.strip(), Role.id != rid).first()
    if duplicate:
        raise HTTPException(400, "角色编码已存在")
    r.name = body.name.strip()
    r.code = body.code.strip()
    r.permissions = dump_json(body.permissions)
    r.remark = body.remark
    db.commit()
    return role_out(r)


@router.delete("/roles/{rid}")
def delete_role(rid: str, _: dict = Depends(require_perm("roles:edit")), db: Session = Depends(get_db)):
    r = db.get(Role, rid)
    if not r:
        raise HTTPException(404, "角色不存在")
    if r.builtin:
        raise HTTPException(400, "系统预置角色不可删除")
    if db.query(Staff).filter(Staff.role_id == rid).first():
        raise HTTPException(400, "该角色仍绑定后台账号，请先调整账号角色")
    db.delete(r)
    db.commit()
    return {"ok": True}


@router.post("/stock-types")
def create_stock_type(body: dict, _: dict = Depends(require_perm("products:edit")), db: Session = Depends(get_db)):
    t = StockBizType(
        id=body.get("id") or new_id("st"),
        name=body.get("name") or "",
        description=body.get("description") or "",
        status=body.get("status") or "active",
        sort=int(body.get("sort") or 0),
    )
    db.add(t)
    db.commit()
    return stock_type_out(t)


@router.put("/stock-types/{tid}")
def update_stock_type(tid: str, body: dict, _: dict = Depends(require_perm("products:edit")), db: Session = Depends(get_db)):
    t = db.get(StockBizType, tid)
    if not t:
        raise HTTPException(404, "类型不存在")
    t.name = body.get("name", t.name)
    t.description = body.get("description", t.description)
    t.status = body.get("status", t.status)
    t.sort = int(body.get("sort", t.sort))
    db.commit()
    return stock_type_out(t)


@router.get("/deposit-rules")
def deposit_rules(_: dict = Depends(require_perm("agents:view")), db: Session = Depends(get_db)):
    rows = db.query(DepositRule).order_by(DepositRule.province, DepositRule.city, DepositRule.scale).all()
    return {"items": [deposit_rule_out(r) for r in rows], "total": len(rows)}


def _rule_dup(db: Session, *, province: str, city: str, scale: str, exclude_id: str = "") -> bool:
    q = db.query(DepositRule).filter(
        DepositRule.province == province,
        DepositRule.city == city,
        DepositRule.scale == scale,
    )
    if exclude_id:
        q = q.filter(DepositRule.id != exclude_id)
    return q.first() is not None


@router.post("/deposit-rules")
def create_deposit_rule(body: dict, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    province = (body.get("province") or "").strip()
    city = (body.get("city") or "").strip()
    if city and not province:
        raise HTTPException(400, "选择城市时请同时选择省份")
    scale = normalize_scale(body.get("scale"))
    if scale not in VALID_SCALES:
        raise HTTPException(400, "合作规模无效")
    try:
        amount = float(body.get("amount") or 0)
    except (TypeError, ValueError) as exc:
        raise HTTPException(400, "押金金额无效") from exc
    if amount <= 0:
        raise HTTPException(400, "押金金额须大于 0")
    if _rule_dup(db, province=province, city=city, scale=scale):
        raise HTTPException(400, "该区域与规模已有规则，请直接编辑")
    r = DepositRule(
        id=body.get("id") or new_id("dr"),
        province=province,
        city=city,
        scale=scale,
        amount=amount,
        remark=(body.get("remark") or "").strip(),
        status=body.get("status") or "active",
    )
    db.add(r)
    db.commit()
    return deposit_rule_out(r)


@router.put("/deposit-rules/{rid}")
def update_deposit_rule(rid: str, body: dict, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    r = db.get(DepositRule, rid)
    if not r:
        raise HTTPException(404, "规则不存在")
    province = ((body.get("province") if "province" in body else r.province) or "").strip()
    city = ((body.get("city") if "city" in body else r.city) or "").strip()
    if city and not province:
        raise HTTPException(400, "选择城市时请同时选择省份")
    scale = normalize_scale(body.get("scale") if "scale" in body else r.scale)
    try:
        amount = float(body.get("amount", r.amount) or 0)
    except (TypeError, ValueError) as exc:
        raise HTTPException(400, "押金金额无效") from exc
    if amount <= 0:
        raise HTTPException(400, "押金金额须大于 0")
    if _rule_dup(db, province=province, city=city, scale=scale, exclude_id=rid):
        raise HTTPException(400, "该区域与规模已有规则，请直接编辑")
    r.province = province
    r.city = city
    r.scale = scale
    r.amount = amount
    r.remark = (body.get("remark") if "remark" in body else r.remark) or ""
    r.status = body.get("status", r.status) or "active"
    db.commit()
    return deposit_rule_out(r)


@router.delete("/deposit-rules/{rid}")
def delete_deposit_rule(rid: str, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    r = db.get(DepositRule, rid)
    if not r:
        raise HTTPException(404, "规则不存在")
    db.delete(r)
    db.commit()
    return {"ok": True}


@router.delete("/stock-types/{tid}")
def delete_stock_type(tid: str, _: dict = Depends(require_perm("products:edit")), db: Session = Depends(get_db)):
    t = db.get(StockBizType, tid)
    if not t:
        raise HTTPException(404, "类型不存在")
    if db.query(Product).filter(Product.stock_type_id == tid).first():
        raise HTTPException(400, "该类型下仍有套餐，请先调整或删除套餐")
    db.delete(t)
    db.commit()
    return {"ok": True}


@router.delete("/merchants/{mid}")
def delete_merchant(mid: str, _: dict = Depends(require_perm("merchants:edit")), db: Session = Depends(get_db)):
    m = db.get(Merchant, mid)
    if not m:
        raise HTTPException(404, "商家不存在")
    db.query(Technician).filter(Technician.merchant_id == mid).delete()
    db.delete(m)
    db.commit()
    return {"ok": True}


@router.delete("/agents/{aid}")
def delete_agent(aid: str, _: dict = Depends(require_perm("agents:edit")), db: Session = Depends(get_db)):
    a = db.get(Agent, aid)
    if not a:
        raise HTTPException(404, "代理不存在")
    db.delete(a)
    db.commit()
    return {"ok": True}


@router.put("/docs/{doc_id}")
def update_doc(doc_id: str, body: dict, _: dict = Depends(require_perm("content:edit")), db: Session = Depends(get_db)):
    d = db.get(ContentDoc, doc_id)
    if not d:
        raise HTTPException(404, "文档不存在")
    d.title = body.get("title", d.title)
    d.updated_at = now_str()
    d.sections = dump_json(body.get("sections") or [])
    db.commit()
    return doc_out(d)


@router.post("/faqs")
def create_faq(body: dict, _: dict = Depends(require_perm("service:edit")), db: Session = Depends(get_db)):
    f = Faq(
        id=body.get("id") or new_id("f"),
        category=body.get("category") or "订单",
        question=body.get("question") or "",
        answer=body.get("answer") or "",
        enabled=bool(body.get("enabled", True)),
        sort=int(body.get("sort") or 0),
    )
    db.add(f)
    db.commit()
    return faq_out(f)


@router.put("/faqs/{fid}")
def update_faq(fid: str, body: dict, _: dict = Depends(require_perm("service:edit")), db: Session = Depends(get_db)):
    f = db.get(Faq, fid)
    if not f:
        raise HTTPException(404, "不存在")
    f.category = body.get("category", f.category)
    f.question = body.get("question", f.question)
    f.answer = body.get("answer", f.answer)
    f.enabled = bool(body.get("enabled", f.enabled))
    f.sort = int(body.get("sort", f.sort))
    db.commit()
    return faq_out(f)


@router.delete("/faqs/{fid}")
def delete_faq(fid: str, _: dict = Depends(require_perm("service:edit")), db: Session = Depends(get_db)):
    f = db.get(Faq, fid)
    if not f:
        raise HTTPException(404, "不存在")
    db.delete(f)
    db.commit()
    return {"ok": True}
