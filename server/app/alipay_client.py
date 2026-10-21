"""支付宝 APP 支付：按 ALIPAY_ENV 选用 mock / sandbox / production 配置。"""

from __future__ import annotations

import logging
import re
from functools import lru_cache

from app.config import settings

logger = logging.getLogger("alipay")


def normalize_pem(key: str, kind: str = "PRIVATE") -> str:
    """接受裸 Base64 或完整 PEM，统一成 PEM 文本。

    kind: PRIVATE → RSA PRIVATE KEY；PUBLIC → PUBLIC KEY（支付宝公钥常见格式）
    """
    text = (key or "").strip().replace("\\n", "\n")
    if not text:
        return ""
    if "BEGIN" in text:
        return text
    body = re.sub(r"\s+", "", text)
    lines = [body[i : i + 64] for i in range(0, len(body), 64)]
    if kind.upper().startswith("PUBLIC"):
        label = "PUBLIC KEY"
    else:
        label = "RSA PRIVATE KEY"
    return f"-----BEGIN {label}-----\n" + "\n".join(lines) + f"\n-----END {label}-----\n"

def alipay_env() -> str:
    env = (settings.alipay_env or "mock").strip().lower()
    if env not in ("mock", "sandbox", "production"):
        return "mock"
    return env


def notify_url() -> str:
    base = (settings.public_base_url or "").rstrip("/")
    path = settings.alipay_notify_path or "/api/pay/alipay/notify"
    if not path.startswith("/"):
        path = "/" + path
    if not base:
        return ""
    return base + path


def _active_credentials() -> tuple[str, str, str, str]:
    env = alipay_env()
    if env == "sandbox":
        return (
            settings.alipay_sandbox_app_id.strip(),
            settings.alipay_sandbox_private_key,
            settings.alipay_sandbox_public_key,
            settings.alipay_sandbox_gateway.strip()
            or "https://openapi-sandbox.dl.alipaydev.com/gateway.do",
        )
    return (
        settings.alipay_app_id.strip(),
        settings.alipay_private_key,
        settings.alipay_public_key,
        settings.alipay_gateway.strip() or "https://openapi.alipay.com/gateway.do",
    )


@lru_cache(maxsize=4)
def _client_for(cache_key: str):
    from alipay import AliPay

    app_id, priv, pub, gateway = _active_credentials()
    if not app_id or not priv or not pub:
        raise RuntimeError(
            f"支付宝 {alipay_env()} 未配置完整：需要 APP_ID、应用私钥、支付宝公钥（见 .env）"
        )
    debug = alipay_env() == "sandbox"
    client = AliPay(
        appid=app_id,
        app_notify_url=notify_url() or None,
        app_private_key_string=normalize_pem(priv, "PRIVATE"),
        alipay_public_key_string=normalize_pem(pub, "PUBLIC"),
        sign_type="RSA2",
        debug=debug,
        verbose=False,
    )
    # python-alipay-sdk 用 debug 切换网关；若自定义 gateway 与默认不一致则覆盖
    if gateway:
        client._gateway = gateway  # noqa: SLF001
    logger.info("Alipay client ready env=%s app_id=%s gateway=%s", alipay_env(), app_id, gateway)
    return client


def get_alipay_client():
    app_id, priv, pub, gateway = _active_credentials()
    cache_key = f"{alipay_env()}|{app_id}|{hash(priv)}|{hash(pub)}|{gateway}"
    return _client_for(cache_key)


def build_app_pay_order_str(
    *,
    out_trade_no: str,
    total_amount: float,
    subject: str,
    body: str = "",
) -> str:
    client = get_alipay_client()
    amount = f"{total_amount:.2f}"
    return client.api_alipay_trade_app_pay(
        subject=subject[:256],
        out_trade_no=out_trade_no,
        total_amount=amount,
        notify_url=notify_url() or None,
        body=(body or subject)[:128],
        product_code="QUICK_MSECURITY_PAY",
        timeout_express="30m",
    )


def verify_notify(data: dict) -> bool:
    """校验异步通知签名。data 为 form 字典（含 sign）。"""
    if not data:
        return False
    client = get_alipay_client()
    return bool(client.verify(data, data.get("sign")))
