from __future__ import annotations

import json
import uuid
from datetime import datetime


def now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def new_id(prefix: str = "") -> str:
    return f"{prefix}{uuid.uuid4().hex[:12]}"


def order_no(biz_type: str) -> str:
    prefix = {
        "haoka": "HK",
        "contract_phone": "HJ",
        "wifi": "WF",
        "cpe": "CPE",
        "stock": "CL",
    }.get(biz_type, "KD")
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"{prefix}{stamp}{uuid.uuid4().hex[:4].upper()}"


def dump_json(value) -> str:
    return json.dumps(value or [], ensure_ascii=False)


def load_json(raw: str | None, default=None):
    if not raw:
        return default if default is not None else []
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return default if default is not None else []


SKIP_TECH = {"broadband_naked", "broadband_no_card"}
REMOTE_COMPLETE = {"haoka", "contract_phone", "stock"}


def skip_tech_dispatch(biz_type: str) -> bool:
    return biz_type in SKIP_TECH


def can_remote_complete(biz_type: str) -> bool:
    return biz_type in REMOTE_COMPLETE


def can_deliver(biz_type: str, status: str) -> bool:
    if status in {"done", "failed", "cancelled", "listed", "merchant_accepted", "dispatched"}:
        return False
    if biz_type == "broadband_new_card":
        return status in {"boss_opened", "installing"}
    if biz_type == "haoka":
        return status == "boss_opened"
    return status == "tech_accepted"
