"""阿里云短信 SendSms（2017-05-25）。模板变量只有 code，且必须是 4–6 位数字。"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

logger = logging.getLogger("sms")

_MESSAGES = {
    "isv.MOBILE_NUMBER_ILLEGAL": "手机号格式不正确",
    "isv.BUSINESS_LIMIT_CONTROL": "发送过于频繁，请稍后再试",
    "isv.AMOUNT_NOT_ENOUGH": "短信套餐余额不足",
    "isv.SMS_SIGNATURE_ILLEGAL": "短信签名不可用",
    "isv.SMS_TEMPLATE_ILLEGAL": "短信模板不可用",
    "isv.TEMPLATE_MISSING_PARAMETERS": "短信模板参数不正确",
    "isv.INVALID_PARAMETERS": "短信参数不正确",
    "isv.SMS_CONTENT_ILLEGAL": "短信内容未通过审核",
    "isp.RAM_PERMISSION_DENY": "短信账号没有发送权限",
    "SignatureDoesNotMatch": "短信密钥校验失败",
    "InvalidAccessKeyId.NotFound": "短信 AccessKey 无效",
    "InvalidAccessKeyId": "短信 AccessKey 无效",
}


class SmsSendError(Exception):
    pass


def _percent_encode(value: str) -> str:
    return urllib.parse.quote(str(value), safe="~")


def _sign(params: dict[str, str], access_key_secret: str) -> str:
    canonical = "&".join(
        f"{_percent_encode(key)}={_percent_encode(params[key])}" for key in sorted(params)
    )
    string_to_sign = f"POST&{_percent_encode('/')}&{_percent_encode(canonical)}"
    digest = hmac.new(
        f"{access_key_secret}&".encode(),
        string_to_sign.encode(),
        hashlib.sha1,
    ).digest()
    return base64.b64encode(digest).decode()


def send_code(
    *,
    phone: str,
    code: str,
    access_key_id: str,
    access_key_secret: str,
    sign_name: str,
    template_code: str,
    endpoint: str = "dysmsapi.aliyuncs.com",
) -> str:
    params = {
        "Action": "SendSms",
        "Version": "2017-05-25",
        "Format": "JSON",
        "AccessKeyId": access_key_id,
        "SignatureMethod": "HMAC-SHA1",
        "SignatureVersion": "1.0",
        "SignatureNonce": uuid.uuid4().hex,
        "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "RegionId": "cn-hangzhou",
        "PhoneNumbers": phone,
        "SignName": sign_name,
        "TemplateCode": template_code,
        "TemplateParam": json.dumps({"code": code}, ensure_ascii=False, separators=(",", ":")),
    }
    params["Signature"] = _sign(params, access_key_secret)
    body = "&".join(f"{_percent_encode(key)}={_percent_encode(params[key])}" for key in params)
    request = urllib.request.Request(
        f"https://{endpoint.strip() or 'dysmsapi.aliyuncs.com'}/",
        data=body.encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw = response.read().decode()
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")
    except urllib.error.URLError as exc:
        logger.warning("sms connect failed: %s", exc.reason)
        raise SmsSendError("短信服务暂时无法连接") from exc

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        logger.warning("sms response not json")
        raise SmsSendError("短信服务返回异常")

    result = str(data.get("Code") or "")
    if result == "OK":
        return str(data.get("BizId") or "")
    logger.warning("sms send failed code=%s request_id=%s", result, data.get("RequestId"))
    raise SmsSendError(_MESSAGES.get(result) or "验证码发送失败")
