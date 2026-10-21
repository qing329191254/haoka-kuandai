"""把 admin/dist 复制到 server/admin_dist，供 FastAPI 同源托管。

打包时不要设置 VITE_API_BASE，这样后台会请求同源 /api。
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT.parent / "admin" / "dist"
DST = ROOT / "admin_dist"


def main() -> None:
    if not (SRC / "index.html").is_file():
        raise SystemExit(
            "未找到 admin/dist/index.html。请先在 admin 目录执行：npm run build\n"
            "不要设置 VITE_API_BASE（生产走同源 /api）。"
        )
    if DST.exists():
        shutil.rmtree(DST)
    shutil.copytree(SRC, DST)
    print(f"已复制 {SRC} -> {DST}")


if __name__ == "__main__":
    main()
