from __future__ import annotations

import logging
import mimetypes
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, Response

from app.config import ROOT, settings
from app.deps import current_payload
from app.oss import oss_store, safe_object_name

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/uploads", tags=["文件上传"])
UPLOAD_DIR = ROOT / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

MAX_IMAGE_BYTES = 8 * 1024 * 1024
CONTENT_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}


def public_origin(request: Request) -> str:
    if settings.public_base_url.strip():
        return settings.public_base_url.strip().rstrip("/")
    return str(request.base_url).rstrip("/")


def sniff_ext(content: bytes, filename: str, content_type: str) -> str:
    if content.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if content[:6] in (b"GIF87a", b"GIF89a"):
        return ".gif"
    if len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return ".webp"
    name = (filename or "").lower()
    for ext in (".jpg", ".jpeg", ".png", ".webp", ".gif"):
        if name.endswith(ext):
            return ".jpg" if ext == ".jpeg" else ext
    return CONTENT_EXTENSIONS.get((content_type or "").split(";")[0].strip().lower(), "")


def media_type_for(filename: str) -> str:
    guessed, _ = mimetypes.guess_type(filename)
    return guessed or "application/octet-stream"


async def _save_image(request: Request, file: UploadFile) -> dict:
    content = await file.read(MAX_IMAGE_BYTES + 1)
    if not content:
        raise HTTPException(400, "图片内容为空")
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(400, "单张图片不能超过 8MB")
    ext = sniff_ext(content, file.filename or "", file.content_type or "")
    if not ext:
        raise HTTPException(400, "仅支持 JPG、PNG、WebP 或 GIF 图片")
    filename = f"{uuid4().hex}{ext}"
    content_type = media_type_for(filename)

    if oss_store.enabled:
        try:
            oss_store.put_bytes(filename, content, content_type=content_type)
        except Exception:
            logger.exception("OSS 上传失败")
            raise HTTPException(502, "对象存储上传失败，请稍后重试") from None
    else:
        (UPLOAD_DIR / filename).write_bytes(content)

    base = public_origin(request)
    # 统一走后端文件接口：私有桶不暴露永久外链，本地文件也可由此读取
    return {
        "url": f"{base}/api/uploads/file/{filename}",
        "name": filename,
        "size": len(content),
        "storage": "oss" if oss_store.enabled else "local",
    }


@router.post("/images")
async def upload_image(
    request: Request,
    file: UploadFile = File(...),
    _: dict = Depends(current_payload),
):
    return await _save_image(request, file)


@router.post("/apply-images")
async def upload_apply_image(request: Request, file: UploadFile = File(...)):
    """入驻申请未登录时上传证件照片。"""
    return await _save_image(request, file)


@router.get("/file/{filename}")
def get_uploaded_file(filename: str):
    """读取已上传图片：OSS 私有桶走服务端代理，未启用 OSS 时读本地。"""
    try:
        name = safe_object_name(filename)
    except ValueError:
        raise HTTPException(404, "文件不存在") from None

    if oss_store.enabled:
        try:
            if not oss_store.exists(name):
                raise HTTPException(404, "文件不存在")
            data = oss_store.get_bytes(name)
        except HTTPException:
            raise
        except Exception:
            logger.exception("OSS 读取失败 name=%s", name)
            raise HTTPException(502, "对象存储读取失败") from None
        return Response(content=data, media_type=media_type_for(name))

    path = UPLOAD_DIR / name
    if not path.is_file():
        raise HTTPException(404, "文件不存在")
    return FileResponse(path, media_type=media_type_for(name))
