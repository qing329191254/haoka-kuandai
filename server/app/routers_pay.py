"""支付回调（无需登录）。"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.orm import Session

from app.alipay_client import alipay_env, verify_notify
from app.db import get_db
from app.models import AgentApplication
from app.util import now_str

logger = logging.getLogger("alipay.notify")
router = APIRouter(prefix="/api/pay", tags=["支付回调"])


@router.post("/alipay/notify")
async def alipay_notify(request: Request, db: Session = Depends(get_db)):
    form = await request.form()
    data = {k: str(v) for k, v in form.items()}
    if alipay_env() == "mock":
        return Response(content="success", media_type="text/plain")

    try:
        ok = verify_notify(dict(data))
    except Exception:
        logger.exception("alipay notify verify error")
        return Response(content="fail", media_type="text/plain")

    if not ok:
        logger.warning("alipay notify bad sign out_trade_no=%s", data.get("out_trade_no"))
        return Response(content="fail", media_type="text/plain")

    trade_status = data.get("trade_status", "")
    out_trade_no = data.get("out_trade_no", "")
    trade_no = data.get("trade_no", "")
    if trade_status not in ("TRADE_SUCCESS", "TRADE_FINISHED"):
        return Response(content="success", media_type="text/plain")

    app = (
        db.query(AgentApplication)
        .filter(AgentApplication.deposit_out_trade_no == out_trade_no)
        .order_by(AgentApplication.created_at.desc())
        .first()
    )
    if not app:
        logger.warning("alipay notify unknown out_trade_no=%s", out_trade_no)
        return Response(content="success", media_type="text/plain")

    if not app.deposit_paid:
        app.deposit_paid = True
        app.deposit_paid_at = now_str()
        app.deposit_trade_no = trade_no or app.deposit_trade_no
        app.deposit_channel = "alipay"
        db.commit()
        logger.info("deposit paid application=%s out_trade_no=%s", app.id, out_trade_no)

    return Response(content="success", media_type="text/plain")
