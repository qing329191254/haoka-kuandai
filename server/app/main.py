import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.config import ROOT, settings
from app.cs_hub import cs_hub
from app.cs_jobs import cs_maintenance_loop
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

logger = logging.getLogger(__name__)

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
    maintenance_task = asyncio.create_task(cs_maintenance_loop(), name="cs-maintenance")
    try:
        yield
    finally:
        maintenance_task.cancel()
        try:
            await maintenance_task
        except asyncio.CancelledError:
            pass
        except Exception:
            logger.debug("cs maintenance task ended with error", exc_info=True)


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


def _read_sha(path: Path) -> str:
    try:
        if path.is_file():
            return path.read_text(encoding="utf-8").strip()[:64]
    except Exception:
        pass
    return ""


def _deploy_zh(status_line: str, api_sha: str, admin_sha: str) -> tuple[str, str]:
    """返回 (code, 中文说明)。code: done / updating / failed / running。"""
    line = (status_line or "").strip()
    low = line.lower()
    if any(
        k in low
        for k in (
            "health failed",
            "import failed",
            "previous code restored",
            "admin_fail",
            "pip install failed",
            "rollback",
        )
    ):
        return "failed", "更新失败（可能已回滚到旧版）"
    if any(
        k in low
        for k in (
            "deploy api",
            "pip install",
            "venv python",
            "building admin",
            "cloning",
            "fetched",
            "newer commit",
            "run again",
            "sync",
        )
    ):
        return "updating", "更新中，请稍候再刷新"
    if api_sha and admin_sha and api_sha != admin_sha:
        return "updating", "后端已更新，后台前端还在更新或构建失败"
    if any(k in low for k in ("api healthy", "api up to date", "admin_dist updated", "no api changes")):
        return "done", "更新完成"
    if api_sha:
        return "running", "服务运行中"
    return "running", "服务运行中"


@app.get("/health")
def health(request: Request, format: str = ""):
    """浏览器打开显示中文状态；加 ?format=json 返回 JSON。"""
    api_sha = _read_sha(ROOT / "deployed_api.sha")
    admin_sha = _read_sha(ROOT / "deployed_admin.sha")
    status_line = ""
    try:
        sp = ROOT / "deploy_status.txt"
        if sp.is_file():
            status_line = sp.read_text(encoding="utf-8").strip().splitlines()[-1][:240]
    except Exception:
        pass
    code, text = _deploy_zh(status_line, api_sha, admin_sha)
    short_api = api_sha[:7] if api_sha else "无"
    short_admin = admin_sha[:7] if admin_sha else "无"
    payload = {
        "ok": True,
        "name": settings.app_name,
        "admin": (ADMIN_DIST / "index.html").is_file(),
        "alipayEnv": alipay_env(),
        "apiSha": api_sha,
        "adminSha": admin_sha,
        "deployStatus": status_line,
        "status": code,
        "statusText": text,
    }

    # 默认 JSON，保证旧版 auto_deploy / 监控脚本不会误判回滚。
    # 仅浏览器（User-Agent 含 Mozilla）或 ?format=html 才返回中文页。
    ua = (request.headers.get("user-agent") or "").lower()
    want_html = format.lower() == "html" or (
        format.lower() != "json" and "mozilla" in ua
    )
    if not want_html:
        return JSONResponse(payload)

    color = {
        "done": "#15803d",
        "updating": "#c2410c",
        "failed": "#b91c1c",
        "running": "#1d4ed8",
    }.get(code, "#334155")

    def esc(s: str) -> str:
        return (
            s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    log_show = esc((status_line or "暂无")[:80])
    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="15" />
  <title>部署状态</title>
  <style>
    body {{ margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      background: linear-gradient(160deg, #f0f7ff, #eef2ff 50%, #f8fafc); color:#0f172a; }}
    .card {{ width:min(520px,92vw); background:#fff; border-radius:20px; padding:36px 32px;
      box-shadow: 0 18px 50px rgba(15,23,42,.08); }}
    .label {{ font-size:14px; color:#64748b; margin-bottom:8px; }}
    .status {{ font-size:36px; font-weight:700; color:{color}; line-height:1.25; margin:0 0 20px; }}
    .row {{ display:flex; justify-content:space-between; gap:12px; padding:10px 0;
      border-top:1px solid #e2e8f0; font-size:14px; }}
    .k {{ color:#64748b; flex-shrink:0; }} .v {{ font-family:ui-monospace,Consolas,monospace; text-align:right; word-break:break-all; }}
    .hint {{ margin-top:18px; font-size:12px; color:#94a3b8; line-height:1.5; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="label">线上部署状态</div>
    <p class="status">{esc(text)}</p>
    <div class="row"><span class="k">后端版本</span><span class="v">{esc(short_api)}</span></div>
    <div class="row"><span class="k">后台前端版本</span><span class="v">{esc(short_admin)}</span></div>
    <div class="row"><span class="k">支付宝环境</span><span class="v">{esc(str(payload["alipayEnv"]))}</span></div>
    <div class="row"><span class="k">最近日志</span><span class="v">{log_show}</span></div>
    <p class="hint">页面每 15 秒自动刷新。看到「更新完成」且两个版本号一致，就是部署成功。</p>
  </div>
</body>
</html>"""
    return HTMLResponse(html)


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
