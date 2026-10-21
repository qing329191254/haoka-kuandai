from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import merchant_of, require_mp_role, require_portal, tech_of
from app.integrations import SmsRateLimit, sms_provider
from app.sms_aliyun import SmsSendError
from app.models import Merchant, MerchantApplication, Order, Technician
from app.schemas import DeliverFailIn, DeliverOkIn, DispatchIn, FollowUpIn, MpApplyIn, MpLoginIn, RemarkIn, SmsIn, TechIn
from app.security import create_token
from app.serialize import merchant_app_out, order_out, tech_out
from app.services import (
    accept_order,
    boss_pc_open,
    complete_remote,
    dispatch_to_tech,
    mark_follow_up,
    mark_install_done,
    mark_needs_dispatch,
    order_in_stage,
    resume_processing,
    tech_accept,
    tech_boss_open,
    tech_deliver_fail,
    tech_deliver_ok,
    visible_for_merchant,
    visible_for_tech,
)
from app.util import dump_json, new_id, now_str

router = APIRouter(prefix="/api/mp", tags=["小程序 商家/师傅"])


@router.post("/auth/sms")
def send_sms(body: SmsIn):
    try:
        sms_provider.send(body.phone)
    except SmsRateLimit:
        raise HTTPException(400, "验证码发送过于频繁，请稍后再试")
    except SmsSendError as exc:
        raise HTTPException(400, str(exc))
    return {"ok": True, "message": "验证码已发送"}


@router.post("/auth/login")
def login(body: MpLoginIn, db: Session = Depends(get_db)):
    if not sms_provider.verify(body.phone, body.code):
        raise HTTPException(400, "验证码错误")
    phone = body.phone.strip()
    if body.role == "merchant":
        m = db.query(Merchant).filter(Merchant.login_phone == phone).first()
        if m:
            if m.status != "active":
                raise HTTPException(403, "门店已停用")
            token = create_token(
                {"sub": m.id, "portal": "mp", "role": "merchant", "merchant_id": m.id, "phone": phone}
            )
            return {
                "token": token,
                "session": {
                    "role": "merchant",
                    "displayName": m.mp_display_name or m.name,
                    "phone": phone,
                    "merchantId": m.id,
                    "auditStatus": "approved",
                },
            }
        app = (
            db.query(MerchantApplication)
            .filter(MerchantApplication.phone == phone)
            .order_by(MerchantApplication.created_at.desc())
            .first()
        )
        if not app:
            raise HTTPException(400, "该手机号未入驻，请先申请商家入驻")
        token = create_token({"sub": app.id, "portal": "mp", "role": "merchant", "phone": phone, "apply_id": app.id})
        return {
            "token": token,
            "session": {
                "role": "merchant",
                "displayName": app.name,
                "phone": phone,
                "auditStatus": app.status,
                "rejectReason": app.reject_reason,
            },
        }
    if body.role == "technician":
        t = db.query(Technician).filter(Technician.phone == phone).first()
        if not t:
            raise HTTPException(400, "该手机号未开通师傅账号，请联系所属商家添加")
        if t.status != "active":
            raise HTTPException(403, "账号已停用")
        token = create_token(
            {"sub": t.id, "portal": "mp", "role": "technician", "tech_id": t.id, "merchant_id": t.merchant_id, "phone": phone}
        )
        return {
            "token": token,
            "session": {
                "role": "technician",
                "displayName": t.name,
                "phone": phone,
                "merchantId": t.merchant_id,
            },
        }
    raise HTTPException(400, "请选择商家或师傅身份")


@router.post("/merchant/apply")
def merchant_apply(body: MpApplyIn, db: Session = Depends(get_db)):
    if not sms_provider.verify(body.phone, body.code):
        raise HTTPException(400, "验证码错误")
    if db.query(Merchant).filter(Merchant.login_phone == body.phone.strip()).first():
        raise HTTPException(400, "该手机号已是入驻商家")
    existing = (
        db.query(MerchantApplication)
        .filter(MerchantApplication.phone == body.phone.strip(), MerchantApplication.status == "pending")
        .first()
    )
    if existing:
        raise HTTPException(400, "该手机号已有待审核申请，请勿重复提交")
    row = MerchantApplication(
        id=new_id("ma"),
        name=body.name,
        phone=body.phone.strip(),
        contact=body.contact,
        province=body.province,
        city=body.city,
        district=body.district,
        address=body.address,
        wechat=body.wechat,
        backup_phone=body.backup_phone,
        id_no=body.id_no,
        license_name=body.license_name,
        remark=body.remark,
        biz_types=dump_json(body.biz_types),
        status="pending",
        created_at=now_str(),
    )
    db.add(row)
    db.commit()
    return merchant_app_out(row)


@router.get("/me")
def me(payload: dict = Depends(require_portal("mp")), db: Session = Depends(get_db)):
    if payload.get("role") == "technician":
        t = tech_of(db, payload)
        return {"role": "technician", "displayName": t.name, "phone": t.phone, "merchantId": t.merchant_id}
    mid = payload.get("merchant_id")
    if mid:
        m = db.get(Merchant, mid)
        if not m or m.status != "active":
            raise HTTPException(403, "门店已停用")
        return {
            "role": "merchant",
            "displayName": m.mp_display_name if m else "",
            "phone": payload.get("phone"),
            "merchantId": mid,
            "auditStatus": "approved",
            "province": m.province if m else "",
            "city": m.city if m else "",
            "district": m.district if m else "",
        }
    app = db.get(MerchantApplication, payload.get("apply_id") or payload.get("sub"))
    return {
        "role": "merchant",
        "displayName": app.name if app else "",
        "phone": payload.get("phone"),
        "auditStatus": app.status if app else "pending",
        "rejectReason": app.reject_reason if app else "",
    }


@router.get("/orders")
def list_orders(
    stage: str = Query(""),
    payload: dict = Depends(require_mp_role("merchant")),
    db: Session = Depends(get_db),
):
    merchant = merchant_of(db, payload)
    rows = visible_for_merchant(db, merchant.id)
    if stage:
        rows = [o for o in rows if order_in_stage(o, stage)]
    return {"items": [order_out(o) for o in rows], "total": len(rows)}


@router.get("/stats")
def merchant_stats(payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    merchant = merchant_of(db, payload)
    all_rows = visible_for_merchant(db, merchant.id)
    return {
        "entry": sum(1 for o in all_rows if order_in_stage(o, "entry")),
        "process": sum(1 for o in all_rows if order_in_stage(o, "process")),
        "dispatch": sum(1 for o in all_rows if order_in_stage(o, "dispatch")),
        "followUp": sum(1 for o in all_rows if o.status in {"follow_up", "failed"}),
        "done": sum(1 for o in all_rows if o.status == "done"),
    }


@router.get("/orders/{oid}")
def mp_order_one(oid: str, payload: dict = Depends(require_portal("mp")), db: Session = Depends(get_db)):
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    if payload.get("role") == "merchant":
        merchant = merchant_of(db, payload)
        allowed = o.id in {row.id for row in visible_for_merchant(db, merchant.id)}
    elif payload.get("role") == "technician":
        tech = tech_of(db, payload)
        allowed = o.id in {row.id for row in visible_for_tech(db, tech)}
    else:
        allowed = False
    if not allowed:
        raise HTTPException(403, "无权查看该订单")
    return order_out(o)


def _order_for_merchant(oid: str, db: Session, payload: dict) -> tuple[Order, Merchant]:
    merchant = merchant_of(db, payload)
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    visible_ids = {x.id for x in visible_for_merchant(db, merchant.id)}
    if o.id not in visible_ids:
        raise HTTPException(403, "无权操作该订单")
    return o, merchant


@router.post("/orders/{oid}/accept")
def api_accept(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    accept_order(o, merchant)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/complete-remote")
def api_complete(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    complete_remote(o, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/needs-dispatch")
def api_dispatch_need(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    mark_needs_dispatch(o, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/follow-up")
def api_follow(oid: str, body: FollowUpIn, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    mark_follow_up(o, body.reason, body.next_at, body.note, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/resume")
def api_resume(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    resume_processing(o, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/dispatch")
def api_dispatch(oid: str, body: DispatchIn, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    tech = db.get(Technician, body.technician_id) if body.technician_id else None
    if not tech:
        tech = db.query(Technician).filter(Technician.merchant_id == merchant.id, Technician.name == body.technician_name).first()
    if not tech or tech.merchant_id != merchant.id:
        raise HTTPException(400, "师傅不存在或不属于当前门店")
    if tech.status != "active":
        raise HTTPException(400, "该师傅已停用，无法派单")
    dispatch_to_tech(o, tech, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/boss-pc")
def api_boss_pc(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    boss_pc_open(o, merchant)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/install-done")
def api_install(oid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    o, merchant = _order_for_merchant(oid, db, payload)
    mark_install_done(o, merchant.mp_display_name or merchant.name)
    db.commit()
    return order_out(o)


@router.post("/orders/{oid}/cancel")
def api_cancel(oid: str, body: RemarkIn, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    from app.services import cancel_order

    o, merchant = _order_for_merchant(oid, db, payload)
    cancel_order(o, body.reason or body.remark, merchant.mp_display_name or merchant.name, "mp")
    db.commit()
    return order_out(o)


@router.get("/technicians")
def list_techs(payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    merchant = merchant_of(db, payload)
    rows = db.query(Technician).filter(Technician.merchant_id == merchant.id).all()
    return {"items": [tech_out(t) for t in rows], "total": len(rows)}


@router.post("/technicians")
def create_tech(body: TechIn, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    merchant = merchant_of(db, payload)
    if db.query(Technician).filter(Technician.phone == body.phone.strip()).first():
        raise HTTPException(400, "该手机号已是师傅账号")
    t = Technician(
        id=new_id("t"),
        name=body.name,
        phone=body.phone.strip(),
        province=body.province or merchant.province,
        city=body.city or merchant.city,
        district=body.district or merchant.district,
        status=body.status,
        merchant_id=merchant.id,
        merchant_name=merchant.mp_display_name or merchant.name,
        skills=dump_json(body.skills),
    )
    db.add(t)
    db.commit()
    return tech_out(t)


@router.put("/technicians/{tid}")
def update_tech(tid: str, body: TechIn, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    merchant = merchant_of(db, payload)
    t = db.get(Technician, tid)
    if not t or t.merchant_id != merchant.id:
        raise HTTPException(404, "师傅不存在")
    t.name = body.name
    t.phone = body.phone.strip()
    t.province = body.province or t.province
    t.city = body.city or t.city
    t.district = body.district or t.district
    t.status = body.status
    t.skills = dump_json(body.skills)
    db.commit()
    return tech_out(t)


@router.delete("/technicians/{tid}")
def delete_tech(tid: str, payload: dict = Depends(require_mp_role("merchant")), db: Session = Depends(get_db)):
    merchant = merchant_of(db, payload)
    t = db.get(Technician, tid)
    if not t or t.merchant_id != merchant.id:
        raise HTTPException(404, "师傅不存在")
    db.delete(t)
    db.commit()
    return {"ok": True}


@router.get("/tech/orders")
def tech_orders(tab: str = "all", payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    tech = tech_of(db, payload)
    rows = visible_for_tech(db, tech)
    tab_status = {
        "todo": {"dispatched"},
        "serving": {"tech_accepted", "boss_opened", "installing"},
        "done": {"done"},
        "returned": {"failed", "follow_up"},
        "failed": {"failed", "follow_up"},
    }
    if tab in tab_status:
        rows = [o for o in rows if o.status in tab_status[tab]]
    return {"items": [order_out(o) for o in rows], "total": len(rows)}


@router.get("/tech/stats")
def tech_stats(payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    tech = tech_of(db, payload)
    rows = visible_for_tech(db, tech)
    return {
        "todo": sum(1 for o in rows if o.status == "dispatched"),
        "serving": sum(1 for o in rows if o.status in {"tech_accepted", "boss_opened", "installing"}),
        "done": sum(1 for o in rows if o.status == "done"),
        "returned": sum(1 for o in rows if o.status in {"failed", "follow_up"}),
    }


def _order_for_tech(oid: str, db: Session, payload: dict) -> tuple[Order, Technician]:
    tech = tech_of(db, payload)
    o = db.get(Order, oid)
    if not o:
        raise HTTPException(404, "订单不存在")
    if o.id not in {x.id for x in visible_for_tech(db, tech)}:
        raise HTTPException(403, "无权操作该任务")
    return o, tech


@router.post("/tech/orders/{oid}/accept")
def tech_accept_api(oid: str, payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    o, tech = _order_for_tech(oid, db, payload)
    tech_accept(o, tech)
    db.commit()
    return order_out(o)


@router.post("/tech/orders/{oid}/boss-open")
def tech_open_api(oid: str, payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    o, tech = _order_for_tech(oid, db, payload)
    tech_boss_open(o, tech)
    db.commit()
    return order_out(o)


@router.post("/tech/orders/{oid}/deliver-ok")
def tech_ok_api(oid: str, body: DeliverOkIn, payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    o, tech = _order_for_tech(oid, db, payload)
    tech_deliver_ok(o, body.photos, tech)
    db.commit()
    return order_out(o)


@router.post("/tech/orders/{oid}/deliver-fail")
def tech_fail_api(oid: str, body: DeliverFailIn, payload: dict = Depends(require_mp_role("technician")), db: Session = Depends(get_db)):
    o, tech = _order_for_tech(oid, db, payload)
    tech_deliver_fail(o, body.reason, tech)
    db.commit()
    return order_out(o)
