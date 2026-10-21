import asyncio
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.config import ROOT, settings
from app.cs_hub import cs_hub
from app.db import Base, SessionLocal, engine
from app import models  # noqa: F401  register all tables
from app.routers_admin import router as admin_router
from app.routers_app import router as app_router
from app.routers_mp import router as mp_router
from app.routers_pay import router as pay_router
from app.routers_public import router as public_router
from app.routers_uploads import UPLOAD_DIR, router as uploads_router
from app.seed import seed_if_empty
from app.alipay_client import alipay_env

ADMIN_DIST = ROOT / "admin_dist"
_SPA_SKIP = {"api", "uploads", "docs", "redoc", "health"}

def _ensure_schema() -> None:
    """兼容已有库：补齐新增列（SQLite / MySQL）。"""
    stmts = [
        "ALTER TABLE feedbacks ADD COLUMN user_id VARCHAR(32) DEFAULT ''",
        "ALTER TABLE feedbacks ADD COLUMN channel VARCHAR(32) DEFAULT 'app_feedback'",
        # MySQL TEXT 不宜带 DEFAULT；失败则忽略（列已存在等）
        "ALTER TABLE feedbacks ADD COLUMN reply TEXT NULL",
        "ALTER TABLE feedbacks ADD COLUMN admin_note TEXT NULL",
        "ALTER TABLE feedbacks ADD COLUMN handled_at VARCHAR(32) DEFAULT ''",
        "ALTER TABLE feedbacks ADD COLUMN handled_by VARCHAR(80) DEFAULT ''",
        "ALTER TABLE agent_applications ADD COLUMN deposit_out_trade_no VARCHAR(64) DEFAULT ''",
        "ALTER TABLE agent_applications ADD COLUMN deposit_trade_no VARCHAR(64) DEFAULT ''",
        "ALTER TABLE agent_applications ADD COLUMN deposit_channel VARCHAR(16) DEFAULT ''",
        "ALTER TABLE agent_applications ADD COLUMN scale VARCHAR(16) DEFAULT 'city'",
    ]
    if engine.dialect.name == "mysql":
        stmts.extend(
            [
                "ALTER TABLE app_users MODIFY avatar_id VARCHAR(255)",
                "ALTER TABLE agents MODIFY license_name VARCHAR(500)",
                "ALTER TABLE agent_applications MODIFY license_name VARCHAR(500)",
                "ALTER TABLE merchant_applications MODIFY license_name VARCHAR(500)",
            ]
        )
    with engine.begin() as conn:
        for sql in stmts:
            try:
                conn.execute(text(sql))
            except Exception:
                pass


Base.metadata.create_all(bind=engine)
_ensure_schema()
_db = SessionLocal()
try:
    seed_if_empty(_db)
finally:
    _db.close()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    cs_hub.bind_loop(asyncio.get_running_loop())
    db = SessionLocal()
    try:
        seed_if_empty(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title=settings.app_name,
    description="派客邦三端统一后端（App / 小程序 / 运营后台）",
    lifespan=lifespan,
)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
star_all = origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if star_all else origins,
    allow_credentials=not star_all,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(public_router)
app.include_router(app_router)
app.include_router(mp_router)
app.include_router(admin_router)
app.include_router(uploads_router)
app.include_router(pay_router)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


@app.get("/health")
def health():
    return {
        "ok": True,
        "name": settings.app_name,
        "admin": (ADMIN_DIST / "index.html").is_file(),
        "alipayEnv": alipay_env(),
    }


def _admin_file(full_path: str) -> Path | None:
    if not (ADMIN_DIST / "index.html").is_file():
        return None
    rel = Path(full_path)
    if rel.is_absolute() or ".." in rel.parts:
        raise HTTPException(404)
    target = (ADMIN_DIST / rel).resolve()
    try:
        target.relative_to(ADMIN_DIST.resolve())
    except ValueError:
        raise HTTPException(404)
    return target


@app.get("/")
def serve_admin_root():
    return serve_admin("")


@app.get("/{full_path:path}")
def serve_admin(full_path: str):
    """运营后台打包文件（admin/dist → server/admin_dist）。Vue history 路由回退到 index.html。"""
    first = full_path.split("/", 1)[0] if full_path else ""
    if first in _SPA_SKIP or full_path == "openapi.json":
        raise HTTPException(404)
    target = _admin_file(full_path)
    if target is None:
        raise HTTPException(404, "后台前端未部署：请先打包 admin 并复制到 server/admin_dist")
    if full_path and target.is_file():
        return FileResponse(target)
    return FileResponse(
        ADMIN_DIST / "index.html",
        headers={"Cache-Control": "no-cache"},
    )
