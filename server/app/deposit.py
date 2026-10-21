"""按城市 + 合作规模匹配入驻押金。"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.config import settings
from app.models import DepositRule

# county=区县代理 city=地市代理 province=省级代理
SCALE_LABELS = {
    "county": "区县级",
    "city": "地市级",
    "province": "省级",
}

VALID_SCALES = tuple(SCALE_LABELS.keys())


def scale_label(code: str) -> str:
    return SCALE_LABELS.get((code or "").strip(), "地市级")


def normalize_scale(raw: str | None) -> str:
    code = (raw or "city").strip().lower()
    return code if code in SCALE_LABELS else "city"


def _rule_score(rule: DepositRule, province: str, city: str) -> int | None:
    rp = (rule.province or "").strip()
    rc = (rule.city or "").strip()
    if rp and rp != province:
        return None
    if rc and rc != city:
        return None
    score = 0
    if rp:
        score += 2
    if rc:
        score += 4
    return score


def quote_deposit(db: Session, *, province: str, city: str, scale: str) -> dict:
    """返回匹配到的押金金额及规则说明。"""
    sc = normalize_scale(scale)
    pv = (province or "").strip()
    ct = (city or "").strip()
    rows = (
        db.query(DepositRule)
        .filter(DepositRule.status == "active", DepositRule.scale == sc)
        .all()
    )
    best: DepositRule | None = None
    best_score = -1
    for r in rows:
        score = _rule_score(r, pv, ct)
        if score is None:
            continue
        if score > best_score:
            best = r
            best_score = score
    if best:
        scope = "全国默认"
        if best.province and best.city:
            scope = f"{best.province}{best.city}"
        elif best.province:
            scope = f"{best.province}全省"
        return {
            "amount": float(best.amount),
            "scale": sc,
            "scaleLabel": scale_label(sc),
            "ruleId": best.id,
            "scope": scope,
        }
    return {
        "amount": float(settings.deposit_amount),
        "scale": sc,
        "scaleLabel": scale_label(sc),
        "ruleId": "",
        "scope": "系统默认",
    }


def deposit_rule_out(r: DepositRule) -> dict:
    scope = "全国"
    if r.province and r.city:
        scope = f"{r.province} / {r.city}"
    elif r.province:
        scope = f"{r.province}（全省）"
    return {
        "id": r.id,
        "province": r.province or "",
        "city": r.city or "",
        "scale": r.scale,
        "scaleLabel": scale_label(r.scale),
        "amount": r.amount,
        "remark": r.remark or "",
        "status": r.status,
        "scope": scope,
    }
