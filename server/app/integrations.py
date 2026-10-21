"""Third-party adapters. SMS / pay / e-sign.

短信：配齐阿里云密钥后发送 6 位验证码，5 分钟过期。
优先写入 Redis；连不上时保存在当前进程，重启后失效。
未配密钥时仍走演示码。ALLOW_DEMO_SMS=true 时，演示码始终可通过校验。
JWT 本身无状态，登录会话不需要 Redis。

支付环境由 ALIPAY_ENV 控制：mock | sandbox | production（改 .env 后重启）。
"""

from __future__ import annotations

import logging
import re
import secrets
import time

from app.alipay_client import alipay_env, build_app_pay_order_str
from app.config import settings
from app.sms_aliyun import SmsSendError, send_code
from app.util import new_id, now_str

logger = logging.getLogger("pay")

_redis = None
_redis_tried = False
_last_sms_at: dict[str, float] = {}
_local_codes: dict[str, tuple[str, float]] = {}


class SmsRateLimit(Exception):
    pass


_PHONE = re.compile(r"^1[3-9]\d{9}$")


def sms_configured() -> bool:
    return bool(
        settings.sms_access_key_id.strip()
        and settings.sms_access_key_secret.strip()
        and settings.sms_sign_name.strip()
        and settings.sms_template_code.strip()
    )


def get_redis():
    global _redis, _redis_tried
    if _redis_tried:
        return _redis
    _redis_tried = True
    try:
        import redis

        client = redis.from_url(settings.redis_url, decode_responses=True, socket_connect_timeout=0.4)
        client.ping()
        _redis = client
    except Exception:
        _redis = None
    return _redis


def _save_code(phone: str, code: str) -> None:
    r = get_redis()
    if r is not None:
        r.setex(f"sms:{phone}", 300, code)
        return
    _local_codes[phone] = (code, time.monotonic() + 300)


def _read_code(phone: str) -> str | None:
    r = get_redis()
    if r is not None:
        return r.get(f"sms:{phone}")
    item = _local_codes.get(phone)
    if item is None:
        return None
    code, expires = item
    if time.monotonic() > expires:
        _local_codes.pop(phone, None)
        return None
    return code


def _drop_code(phone: str) -> None:
    r = get_redis()
    if r is not None:
        r.delete(f"sms:{phone}")
        return
    _local_codes.pop(phone, None)


class SmsProvider:
    def send(self, phone: str) -> str:
        key = phone.strip()
        if not _PHONE.fullmatch(key):
            raise SmsSendError("请输入正确的手机号")
        now = time.monotonic()
        last = _last_sms_at.get(key, 0)
        if now - last < 55:
            raise SmsRateLimit()
        _last_sms_at[key] = now
        if not sms_configured():
            _save_code(key, settings.demo_sms_code)
            return settings.demo_sms_code
        code = str(secrets.randbelow(900000) + 100000)
        try:
            send_code(
                phone=key,
                code=code,
                access_key_id=settings.sms_access_key_id.strip(),
                access_key_secret=settings.sms_access_key_secret.strip(),
                sign_name=settings.sms_sign_name.strip(),
                template_code=settings.sms_template_code.strip(),
                endpoint=settings.sms_endpoint.strip() or "dysmsapi.aliyuncs.com",
            )
        except SmsSendError:
            _last_sms_at.pop(key, None)
            raise
        _save_code(key, code)
        return code

    def verify(self, phone: str, code: str) -> bool:
        text = code.strip()
        if settings.allow_demo_sms and text == settings.demo_sms_code:
            return True
        key = phone.strip()
        stored = _read_code(key)
        if not stored or stored != text:
            return False
        _drop_code(key)
        return True


class PayProvider:
    """押金支付。

    - mock：立即成功（本地开发默认）
    - sandbox / production：返回 orderStr，须 App 调起支付宝；到账以异步通知为准
    - wechat：暂未开通时返回明确错误（mock 下可选模拟成功）
    """

    def create_deposit(
        self,
        amount: float,
        *,
        channel: str = "alipay",
        out_trade_no: str | None = None,
        subject: str = "派客邦入驻保证金",
    ) -> dict:
        ch = (channel or "alipay").strip().lower()
        env = alipay_env()
        trade_no = out_trade_no or new_id("PAY")

        if ch == "wechat":
            if env == "mock":
                return {
                    "channel": "wechat",
                    "env": env,
                    "amount": amount,
                    "outTradeNo": trade_no,
                    "tradeNo": trade_no,
                    "paid": True,
                    "paidAt": now_str(),
                    "orderStr": "",
                    "needClientPay": False,
                }
            raise ValueError("微信支付暂未开通，请使用支付宝或将 ALIPAY_ENV 设为 mock 联调")

        if ch != "alipay":
            raise ValueError("不支持的支付方式")

        if env == "mock":
            return {
                "channel": "alipay",
                "env": env,
                "amount": amount,
                "outTradeNo": trade_no,
                "tradeNo": trade_no,
                "paid": True,
                "paidAt": now_str(),
                "orderStr": "",
                "needClientPay": False,
            }

        pay_amount = float(settings.alipay_sandbox_amount) if env == "sandbox" else float(amount)
        order_str = build_app_pay_order_str(
            out_trade_no=trade_no,
            total_amount=pay_amount,
            subject=subject,
            body=subject,
        )
        logger.info(
            "alipay app pay created env=%s out_trade_no=%s amount=%s",
            env,
            trade_no,
            pay_amount,
        )
        return {
            "channel": "alipay",
            "env": env,
            "amount": pay_amount,
            "listAmount": float(amount),
            "outTradeNo": trade_no,
            "tradeNo": "",
            "paid": False,
            "paidAt": "",
            "orderStr": order_str,
            "needClientPay": True,
        }


class ESignProvider:
    def sign_contract(self, signer_name: str) -> dict:
        # TODO: 对接法大大 / e签宝
        return {
            "channel": "mock",
            "contractNo": f"HT{new_id('')[:8].upper()}",
            "signerName": signer_name,
            "signedAt": now_str(),
        }


sms_provider = SmsProvider()
pay_provider = PayProvider()
esign_provider = ESignProvider()

logger.info("PayProvider ready ALIPAY_ENV=%s", alipay_env())
