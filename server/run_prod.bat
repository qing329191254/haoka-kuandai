@echo off
cd /d %~dp0
if not exist admin_dist\index.html (
  echo 后台前端未部署：请先在 admin 目录 npm run build，再执行 python copy_admin.py
  exit /b 1
)
if exist .venv\Scripts\uvicorn.exe (
  .venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8888
) else (
  uvicorn app.main:app --host 0.0.0.0 --port 8888
)
