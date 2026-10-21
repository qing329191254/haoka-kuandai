from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.deposit import SCALE_LABELS, quote_deposit
from app.models import ContentDoc, Faq, Merchant, Product, ServiceConfig, StockBizType, AppVersionConfig
from app.serialize import (
    app_version_out,
    doc_out,
    faq_out,
    merchant_out,
    product_out,
    service_out,
    stock_type_out,
)

router = APIRouter(prefix="/api", tags=["公共"])


@router.get("/products")
def products(
    biz_type: str | None = Query(None, alias="bizType"),
    province: str = "",
    city: str = "",
    db: Session = Depends(get_db),
):
    q = db.query(Product).filter(Product.status == "active")
    if biz_type:
        q = q.filter(Product.biz_type == biz_type)
    if province:
        q = q.filter(Product.province == province)
    if city:
        q = q.filter(Product.city == city)
    rows = q.all()
    return {"items": [product_out(p) for p in rows], "total": len(rows)}


@router.get("/merchants")
def merchants(province: str = "", city: str = "", db: Session = Depends(get_db)):
    q = db.query(Merchant).filter(Merchant.status == "active")
    if province:
        q = q.filter(Merchant.province == province)
    if city:
        q = q.filter(Merchant.city == city)
    rows = q.all()
    return {"items": [merchant_out(m) for m in rows], "total": len(rows)}


@router.get("/deposit-quote")
def deposit_quote(
    province: str = "",
    city: str = "",
    scale: str = "city",
    db: Session = Depends(get_db),
):
    """入驻前按城市 + 合作规模预估应缴押金。"""
    quoted = quote_deposit(db, province=province, city=city, scale=scale)
    return {
        **quoted,
        "scales": [{"id": k, "label": v} for k, v in SCALE_LABELS.items()],
    }


@router.get("/stock-types")
def stock_types(db: Session = Depends(get_db)):
    rows = db.query(StockBizType).filter(StockBizType.status == "active").order_by(StockBizType.sort).all()
    return {"items": [stock_type_out(t) for t in rows], "total": len(rows)}


@router.get("/content/docs")
def docs(db: Session = Depends(get_db)):
    return {"items": [doc_out(d) for d in db.query(ContentDoc).all()]}


@router.get("/content/docs/{doc_id}")
def doc_one(doc_id: str, db: Session = Depends(get_db)):
    d = db.get(ContentDoc, doc_id)
    return doc_out(d) if d else {"id": doc_id, "title": "", "sections": []}


@router.get("/content/faqs")
def faqs(db: Session = Depends(get_db)):
    rows = db.query(Faq).filter(Faq.enabled.is_(True)).order_by(Faq.sort).all()
    return {"items": [faq_out(f) for f in rows]}


@router.get("/content/service")
def service(db: Session = Depends(get_db)):
    s = db.get(ServiceConfig, 1)
    return service_out(s) if s else {"hotline": "", "workTime": "", "quickReplies": []}


@router.get("/content/app-version")
def app_version(db: Session = Depends(get_db)):
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
            "enabled": False,
        }
    return app_version_out(v)
