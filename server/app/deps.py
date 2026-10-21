from __future__ import annotations

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import InvalidTokenError
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import AppUser, Merchant, Role, Staff, Technician
from app.security import decode_token

bearer = HTTPBearer(auto_error=False)


def current_payload(
    cred: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> dict:
    if cred is None:
        raise HTTPException(401, "请先登录")
    try:
        return decode_token(cred.credentials)
    except InvalidTokenError:
        raise HTTPException(401, "登录已过期，请重新登录")


def require_portal(*portals: str):
    def _dep(payload: dict = Depends(current_payload)) -> dict:
        if payload.get("portal") not in portals:
            raise HTTPException(403, "无权访问")
        return payload

    return _dep


def require_mp_role(*roles: str):
    def _dep(payload: dict = Depends(require_portal("mp"))) -> dict:
        if payload.get("role") not in roles:
            raise HTTPException(403, "请使用对应身份登录")
        return payload

    return _dep


def require_perm(perm: str):
    def _dep(
        payload: dict = Depends(require_portal("admin")),
        db: Session = Depends(get_db),
    ) -> dict:
        staff = db.get(Staff, payload.get("sub"))
        if not staff or staff.status != "active":
            raise HTTPException(403, "账号已停用")
        role = db.get(Role, staff.role_id)
        perms = []
        if role:
            import json

            perms = json.loads(role.permissions or "[]")
        if "*" not in perms and perm not in perms:
            raise HTTPException(403, "没有权限")
        payload["staff"] = staff
        payload["permissions"] = perms
        return payload

    return _dep


def app_user_of(db: Session, payload: dict) -> AppUser:
    user = db.get(AppUser, payload.get("sub") or "")
    if not user:
        raise HTTPException(401, "登录已过期，请重新登录")
    if user.status != "active":
        raise HTTPException(403, "账号已停用")
    return user


def merchant_of(db: Session, payload: dict) -> Merchant:
    if not payload.get("merchant_id"):
        raise HTTPException(403, "入驻审核通过后方可使用")
    m = db.get(Merchant, payload.get("merchant_id") or "")
    if not m:
        raise HTTPException(403, "入驻审核通过后方可使用")
    if m.status != "active":
        raise HTTPException(403, "门店已停用")
    return m


def tech_of(db: Session, payload: dict) -> Technician:
    t = db.get(Technician, payload.get("tech_id") or "")
    if not t:
        raise HTTPException(400, "师傅账号不存在")
    if t.status != "active":
        raise HTTPException(403, "账号已停用")
    return t
