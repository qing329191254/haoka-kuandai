from __future__ import annotations

from app.deposit import scale_label
from app.models import (
    Agent,
    AgentApplication,
    AppUser,
    AppVersionConfig,
    ContentDoc,
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
)
from app.util import load_json


def audit_of(app: AgentApplication | None) -> str:
    if app is None:
        return "need_contract"
    if app.status == "approved":
        return "approved"
    if app.status == "rejected":
        return "rejected"
    if not app.contract_signed:
        return "need_contract"
    if not app.deposit_paid:
        return "need_deposit"
    return "pending"


def app_user_out(user: AppUser, application: AgentApplication | None) -> dict:
    a = application
    status = audit_of(a)
    return {
        "id": user.id,
        "nickname": user.nickname,
        "phone": user.phone,
        "email": user.email,
        "gender": user.gender,
        "avatarId": user.avatar_id,
        "companyName": user.company_name,
        "auditStatus": status,
        "rejectReason": (a.reject_reason if a else ""),
        "depositAmount": a.deposit_amount if a else 5000,
        "depositPaid": bool(a.deposit_paid) if a else False,
        "depositPaidAt": (a.deposit_paid_at or "") if a else "",
        "scale": (a.scale or "city") if a else "city",
        "scaleLabel": scale_label((a.scale or "city") if a else "city"),
        "contractSigned": bool(a.contract_signed) if a else False,
        "contractSignedAt": (a.contract_signed_at or "") if a else "",
        "contractNo": (a.contract_no or "") if a else "",
        "signerName": (a.signer_name or "") if a else "",
        "canPlaceOrder": status == "approved",
        "agentId": user.agent_id,
    }


def order_out(o: Order) -> dict:
    return {
        "id": o.id,
        "orderNo": o.order_no,
        "bizType": o.biz_type,
        "status": o.status,
        "customerName": o.customer_name,
        "customerPhone": o.customer_phone,
        "customerIdNo": o.customer_id_no,
        "address": o.address,
        "productId": o.product_id,
        "productName": o.product_name,
        "carrier": o.carrier,
        "needNewCard": o.need_new_card,
        "assignedMerchantId": o.assigned_merchant_id,
        "assignedMerchantName": o.assigned_merchant_name,
        "merchantName": o.merchant_name,
        "technicianId": o.technician_id,
        "technicianName": o.technician_name,
        "createdAt": o.created_at,
        "updatedAt": o.updated_at,
        "remark": o.remark,
        "source": o.source,
        "region": o.region,
        "province": o.province,
        "city": o.city,
        "district": o.district,
        "commission": o.commission,
        "stockTypeId": o.stock_type_id or None,
        "stockTypeName": o.stock_type_name or None,
        "failReason": o.fail_reason or None,
        "needsDispatch": o.needs_dispatch,
        "followUpReason": o.follow_up_reason or None,
        "nextFollowUpAt": o.next_follow_up_at or None,
        "followUpLogs": load_json(o.follow_up_logs),
        "deliveryPhotos": load_json(o.delivery_photos),
        "logs": load_json(o.logs),
        "orderIntent": o.order_intent or None,
        "phoneBrand": o.phone_brand or None,
        "priceRange": o.price_range or None,
        "wifiDeviceType": o.wifi_device_type or None,
        "wifiBizMode": o.wifi_biz_mode or None,
        "agentId": o.agent_id,
        "createdByUserId": o.created_by_user_id,
    }


def product_out(p: Product) -> dict:
    return {
        "id": p.id,
        "name": p.name,
        "bizType": p.biz_type,
        "stockTypeId": p.stock_type_id,
        "carrier": p.carrier,
        "priceLabel": p.price_label,
        "description": p.description,
        "status": p.status,
        "province": p.province,
        "city": p.city,
        "commission": p.commission,
        "wifiDeviceType": p.wifi_device_type or None,
        "wifiBizMode": p.wifi_biz_mode or None,
    }


def merchant_out(m: Merchant) -> dict:
    return {
        "id": m.id,
        "name": m.name,
        "phone": m.phone,
        "loginPhone": m.login_phone,
        "province": m.province,
        "city": m.city,
        "district": m.district,
        "address": m.address,
        "status": m.status,
        "bizTypes": load_json(m.biz_types),
        "contact": m.contact,
        "mpDisplayName": m.mp_display_name,
    }


def tech_out(t: Technician) -> dict:
    return {
        "id": t.id,
        "name": t.name,
        "phone": t.phone,
        "province": t.province,
        "city": t.city,
        "district": t.district,
        "status": t.status,
        "merchantId": t.merchant_id,
        "merchantName": t.merchant_name,
        "skills": load_json(t.skills),
    }


def agent_out(a: Agent) -> dict:
    return {
        "id": a.id,
        "name": a.name,
        "phone": a.phone,
        "contact": a.contact,
        "province": a.province,
        "city": a.city,
        "district": a.district,
        "address": a.address,
        "wechat": a.wechat,
        "backupPhone": a.backup_phone,
        "idNo": a.id_no,
        "licenseName": a.license_name,
        "joinedAt": a.joined_at,
        "orderCount": a.order_count,
        "status": a.status,
        "remark": a.remark,
    }


def agent_app_out(a: AgentApplication) -> dict:
    return {
        "id": a.id,
        "phone": a.phone,
        "contact": a.contact,
        "name": a.name,
        "province": a.province,
        "city": a.city,
        "district": a.district,
        "address": a.address,
        "wechat": a.wechat,
        "backupPhone": a.backup_phone,
        "idNo": a.id_no,
        "licenseName": a.license_name,
        "remark": a.remark,
        "status": a.status,
        "rejectReason": a.reject_reason or None,
        "createdAt": a.created_at,
        "reviewedAt": a.reviewed_at,
        "agentId": a.agent_id,
        "scale": a.scale or "city",
        "scaleLabel": scale_label(a.scale or "city"),
        "depositAmount": a.deposit_amount,
        "depositPaid": a.deposit_paid,
        "depositPaidAt": a.deposit_paid_at,
        "contractSigned": a.contract_signed,
        "contractSignedAt": a.contract_signed_at,
        "contractNo": a.contract_no,
        "signerName": a.signer_name,
    }


def merchant_app_out(a: MerchantApplication) -> dict:
    return {
        "id": a.id,
        "name": a.name,
        "phone": a.phone,
        "contact": a.contact,
        "province": a.province,
        "city": a.city,
        "district": a.district,
        "address": a.address,
        "wechat": a.wechat,
        "backupPhone": a.backup_phone,
        "idNo": a.id_no,
        "licenseName": a.license_name,
        "remark": a.remark,
        "bizTypes": load_json(a.biz_types),
        "status": a.status,
        "rejectReason": a.reject_reason or None,
        "createdAt": a.created_at,
        "reviewedAt": a.reviewed_at,
        "merchantId": a.merchant_id,
    }


def stock_type_out(t: StockBizType) -> dict:
    return {"id": t.id, "name": t.name, "description": t.description, "status": t.status, "sort": t.sort}


def faq_out(f: Faq) -> dict:
    return {
        "id": f.id,
        "category": f.category,
        "question": f.question,
        "answer": f.answer,
        "enabled": f.enabled,
        "sort": f.sort,
    }


def feedback_out(f: Feedback) -> dict:
    return {
        "id": f.id,
        "type": f.type,
        "content": f.content,
        "contact": f.contact,
        "userName": f.user_name,
        "userId": getattr(f, "user_id", "") or "",
        "channel": getattr(f, "channel", "") or "app_feedback",
        "createdAt": f.created_at,
        "status": f.status,
        "reply": getattr(f, "reply", "") or "",
        "adminNote": getattr(f, "admin_note", "") or "",
        "handledAt": getattr(f, "handled_at", "") or "",
        "handledBy": getattr(f, "handled_by", "") or "",
    }


def doc_out(d: ContentDoc) -> dict:
    return {"id": d.id, "title": d.title, "updatedAt": d.updated_at, "sections": load_json(d.sections)}


def service_out(s: ServiceConfig) -> dict:
    return {"hotline": s.hotline, "workTime": s.work_time, "quickReplies": load_json(s.quick_replies)}


def app_version_out(v: AppVersionConfig) -> dict:
    return {
        "latestVersion": v.latest_version or "1.0.0",
        "minSupportedVersion": v.min_supported_version or "1.0.0",
        "forceUpdate": False,
        "title": v.title or "发现新版本",
        "releaseNotes": v.release_notes or "",
        "androidUrl": "",
        "iosUrl": v.ios_url or "",
        "enabled": bool(v.enabled),
    }


def warehouse_out(w: WarehouseItem) -> dict:
    return {
        "id": w.id,
        "productId": w.product_id,
        "productName": w.product_name,
        "sku": w.sku,
        "spec": w.spec,
        "stock": w.stock,
        "safetyStock": w.safety_stock,
        "location": w.location,
        "updatedAt": w.updated_at,
    }


def stock_record_out(r: StockRecord) -> dict:
    return {
        "id": r.id,
        "type": r.type,
        "warehouseId": r.warehouse_id,
        "productId": r.product_id,
        "productName": r.product_name,
        "sku": r.sku,
        "qty": r.qty,
        "orderNo": r.order_no or None,
        "operator": r.operator,
        "remark": r.remark,
        "createdAt": r.created_at,
    }


def staff_out(s: Staff, role: Role | None = None) -> dict:
    return {
        "id": s.id,
        "username": s.username,
        "name": s.name,
        "roleId": s.role_id,
        "roleName": role.name if role else "",
        "status": s.status,
        "createdAt": s.created_at,
    }


def role_out(r: Role) -> dict:
    return {
        "id": r.id,
        "name": r.name,
        "code": r.code,
        "builtin": r.builtin,
        "permissions": load_json(r.permissions),
        "remark": r.remark,
    }


def app_user_admin_out(u: AppUser, order_count: int = 0) -> dict:
    return {
        "id": u.id,
        "nickname": u.nickname,
        "phone": u.phone,
        "email": u.email,
        "gender": u.gender,
        "createdAt": u.created_at,
        "orderCount": order_count,
        "status": u.status,
    }
