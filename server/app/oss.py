"""阿里云 OSS 封装。密钥未配齐时 enabled=False，上传回退本地磁盘。"""

from __future__ import annotations

import logging
import re

from app.config import settings

logger = logging.getLogger(__name__)

_SAFE_NAME = re.compile(r"^[a-f0-9]{32}\.(jpg|jpeg|png|webp|gif)$", re.I)


def safe_object_name(filename: str) -> str:
    name = (filename or "").strip().split("/")[-1].split("\\")[-1]
    if not _SAFE_NAME.match(name):
        raise ValueError("非法文件名")
    if name.lower().endswith(".jpeg"):
        name = name[: -5] + ".jpg"
    return name


def object_key(filename: str) -> str:
    name = safe_object_name(filename)
    prefix = (settings.oss_prefix or "uploads").strip().strip("/")
    return f"{prefix}/{name}" if prefix else name


class OssStore:
    def __init__(self) -> None:
        self._bucket_obj = None

    @property
    def enabled(self) -> bool:
        return bool(
            settings.oss_access_key_id.strip()
            and settings.oss_access_key_secret.strip()
            and settings.oss_bucket.strip()
            and settings.oss_endpoint.strip()
        )

    def _bucket(self):
        if self._bucket_obj is None:
            import oss2

            auth = oss2.Auth(
                settings.oss_access_key_id.strip(),
                settings.oss_access_key_secret.strip(),
            )
            endpoint = settings.oss_endpoint.strip()
            self._bucket_obj = oss2.Bucket(auth, endpoint, settings.oss_bucket.strip())
        return self._bucket_obj

    def put_bytes(self, filename: str, content: bytes, content_type: str = "") -> str:
        key = object_key(filename)
        headers = {}
        ct = (content_type or "").split(";")[0].strip()
        if ct:
            headers["Content-Type"] = ct
        self._bucket().put_object(key, content, headers=headers or None)
        return key

    def get_bytes(self, filename: str) -> bytes:
        key = object_key(filename)
        result = self._bucket().get_object(key)
        return result.read()

    def exists(self, filename: str) -> bool:
        key = object_key(filename)
        return bool(self._bucket().object_exists(key))

    def sign_url(self, filename: str, expires: int | None = None) -> str:
        key = object_key(filename)
        seconds = expires if expires is not None else settings.oss_sign_expires
        return self._bucket().sign_url("GET", key, seconds)


oss_store = OssStore()
