from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models import Merchant, Order, Technician
from app.util import can_deliver, can_remote_complete, dump_json, load_json, now_str, skip_tech_dispatch


def append_log(order: Order, actor: str, action: str, channel: str) -> None:
    logs = load_json(order.logs)
    logs.append({"time": now_str(), "actor": actor, "action": action, "channel": channel})
    order.logs = dump_json(logs)
    order.updated_at = now_str()


def append_follow(order: Order, note: str, actor: str) -> None:
    logs = load_json(order.follow_up_logs)
    logs.append({"time": now_str(), "note": note, "actor": actor})
    order.follow_up_logs = dump_json(logs)


def visible_for_merchant(db: Session, merchant_id: str) -> list[Order]:
    merchant = db.get(Merchant, merchant_id)
    rows = (
        db.query(Order)
        .filter(
            (Order.assigned_merchant_id == merchant_id)
            | (
                (Order.biz_type == "haoka")
                & (Order.status == "listed")
                & ((Order.assigned_merchant_id.is_(None)) | (Order.assigned_merchant_id == ""))
            )
        )
        .all()
    )
    out = []
    for o in rows:
        if o.assigned_merchant_id:
            if o.assigned_merchant_id == merchant_id:
                out.append(o)
            continue
        if o.biz_type != "haoka" or o.status != "listed":
            continue
        if merchant and o.province and merchant.province and o.province != merchant.province:
            continue
        if merchant and o.city and merchant.city and o.city != merchant.city:
            continue
        out.append(o)
    return out


def visible_for_tech(db: Session, tech: Technician) -> list[Order]:
    rows = db.query(Order).all()
    name = tech.name
    out = []
    for o in rows:
        if skip_tech_dispatch(o.biz_type):
            continue
        if o.status == "dispatched":
            assigned = o.technician_id == tech.id if o.technician_id else o.technician_name == name
            if assigned:
                out.append(o)
            continue
        assigned = o.technician_id == tech.id if o.technician_id else o.technician_name == name
        returned = assigned and o.status in {"failed", "follow_up"}
        if returned:
            out.append(o)
            continue
        if o.status in {"tech_accepted", "boss_opened", "installing", "done", "failed"} and assigned:
            out.append(o)
    return out


def bind_merchant(order: Order, merchant: Merchant) -> None:
    order.merchant_name = merchant.mp_display_name or merchant.name
    order.assigned_merchant_id = merchant.id
    order.assigned_merchant_name = merchant.mp_display_name or merchant.name


def accept_order(order: Order, merchant: Merchant) -> None:
    if order.status != "listed":
        raise HTTPException(400, "当前状态不可接单")
    if order.assigned_merchant_id and order.assigned_merchant_id != merchant.id:
        raise HTTPException(403, "该订单已指定其他门店")
    order.status = "merchant_accepted"
    order.needs_dispatch = False
    bind_merchant(order, merchant)
    append_log(order, merchant.mp_display_name or merchant.name, "接单", "mp")


def complete_remote(order: Order, actor: str) -> None:
    if order.status != "merchant_accepted" or order.needs_dispatch:
        raise HTTPException(400, "当前不可办结")
    if skip_tech_dispatch(order.biz_type):
        raise HTTPException(400, "该业务需按装机流程办理")
    if not can_remote_complete(order.biz_type):
        raise HTTPException(400, "该业务需派师傅上门，不可远程办结")
    order.status = "done"
    order.fail_reason = ""
    order.follow_up_reason = ""
    append_log(order, actor, "远程办结", "mp")


def mark_needs_dispatch(order: Order, actor: str) -> None:
    if skip_tech_dispatch(order.biz_type):
        raise HTTPException(400, "该业务不派师傅上门")
    if order.status not in {"merchant_accepted", "follow_up", "failed"}:
        raise HTTPException(400, "当前不可标记需上门")
    order.status = "merchant_accepted"
    order.needs_dispatch = True
    order.follow_up_reason = ""
    append_follow(order, "需上门", actor)
    append_log(order, actor, "需上门", "mp")


def mark_follow_up(order: Order, reason: str, next_at: str, note: str, actor: str) -> None:
    if order.status not in {"merchant_accepted", "follow_up", "failed"}:
        raise HTTPException(400, "当前不可跟进")
    order.status = "follow_up"
    order.follow_up_reason = reason.strip()
    order.next_follow_up_at = next_at.strip()
    order.needs_dispatch = False
    append_follow(order, note.strip() or reason, actor)
    append_log(order, actor, f"跟进：{reason}", "mp")


def resume_processing(order: Order, actor: str) -> None:
    if order.status not in {"follow_up", "failed"}:
        raise HTTPException(400, "当前不可恢复")
    order.status = "merchant_accepted"
    order.needs_dispatch = False
    append_follow(order, "恢复办理", actor)
    append_log(order, actor, "恢复办理", "mp")


def dispatch_to_tech(order: Order, tech: Technician, actor: str) -> None:
    if order.status != "merchant_accepted" or not order.needs_dispatch:
        raise HTTPException(400, "请先确认需上门再派单")
    if skip_tech_dispatch(order.biz_type):
        raise HTTPException(400, "该业务不派师傅")
    order.status = "dispatched"
    order.technician_id = tech.id
    order.technician_name = tech.name
    append_log(order, actor, f"派单给{tech.name}", "mp")


def boss_pc_open(order: Order, merchant: Merchant) -> None:
    if not skip_tech_dispatch(order.biz_type):
        raise HTTPException(400, "该业务不走电脑端开户")
    if order.status == "listed":
        accept_order(order, merchant)
    if order.status != "merchant_accepted":
        raise HTTPException(400, "当前不可开户")
    bind_merchant(order, merchant)
    order.status = "boss_opened"
    append_log(order, merchant.mp_display_name or merchant.name, "电脑端开户", "mp")


def mark_install_done(order: Order, actor: str) -> None:
    if order.biz_type not in {"broadband_new_card", "broadband_naked", "broadband_no_card"}:
        raise HTTPException(400, "该业务无需确认装机")
    if order.status not in {"boss_opened", "installing"}:
        raise HTTPException(400, "当前不可确认装机")
    order.status = "done"
    append_log(order, actor, "确认装机完成", "mp")


def tech_accept(order: Order, tech: Technician) -> None:
    if order.status != "dispatched":
        raise HTTPException(400, "当前不可接单上门")
    if order.technician_name and order.technician_name != tech.name:
        raise HTTPException(400, "该单已被其他师傅接走")
    order.status = "tech_accepted"
    order.technician_id = tech.id
    order.technician_name = tech.name
    append_log(order, tech.name, "接单上门", "mp")


def tech_boss_open(order: Order, tech: Technician) -> None:
    if order.status != "tech_accepted":
        raise HTTPException(400, "当前不可开户")
    if order.biz_type not in {"haoka", "broadband_new_card"}:
        raise HTTPException(400, "该业务无需手机开户")
    order.status = "boss_opened"
    append_log(order, tech.name, "手机端开户", "mp")


def tech_deliver_ok(order: Order, photos: list[str], tech: Technician) -> None:
    if not can_deliver(order.biz_type, order.status):
        raise HTTPException(400, "当前不可交付")
    if not photos:
        raise HTTPException(400, "交付成功请至少上传 1 张现场照片")
    order.delivery_photos = dump_json(photos)
    order.status = "done"
    order.fail_reason = ""
    append_log(order, tech.name, "交付成功", "mp")


def tech_deliver_fail(order: Order, reason: str, tech: Technician) -> None:
    if not can_deliver(order.biz_type, order.status):
        raise HTTPException(400, "当前不可退回")
    text = reason.strip()
    if not text:
        raise HTTPException(400, "请填写退回原因")
    order.fail_reason = text
    order.follow_up_reason = text
    order.status = "follow_up"
    order.needs_dispatch = False
    append_follow(order, f"上门未成功：{text}", tech.name)
    append_log(order, tech.name, "交回商家跟进", "mp")


def cancel_order(order: Order, remark: str, actor: str, channel: str) -> None:
    if order.status in {"done", "cancelled"}:
        raise HTTPException(400, "该订单不可取消")
    order.status = "cancelled"
    if remark.strip():
        order.remark = remark.strip()
    append_log(order, actor, f"取消订单{('：' + remark) if remark else ''}", channel)


def order_in_stage(order: Order, stage: str) -> bool:
    if order.status in {"done", "cancelled"}:
        return False
    if stage == "entry":
        return order.status == "listed"
    if stage == "process":
        if order.status in {"follow_up", "failed"}:
            return True
        if skip_tech_dispatch(order.biz_type):
            return order.status in {"merchant_accepted", "boss_opened", "installing"}
        return order.status == "merchant_accepted" and not order.needs_dispatch
    if stage == "dispatch":
        if skip_tech_dispatch(order.biz_type):
            return False
        if order.status == "merchant_accepted" and order.needs_dispatch:
            return True
        return order.status in {"dispatched", "tech_accepted", "boss_opened", "installing"}
    return True
