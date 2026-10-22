@echo off
cd /d C:\haoka\server
set "VIRTUAL_ENV=C:\haoka\server\.venv"
set "PATH=C:\haoka\server\.venv\Scripts;%PATH%"
REM 只用 venv 里的解释器，避免再拉起系统 Python312 抢 443
"C:\haoka\server\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 443 --ssl-certfile "C:\certs\www.lcnh-platform.cn.pem" --ssl-keyfile "C:\certs\www.lcnh-platform.cn.key" > C:\haoka\server\uvicorn.out.log 2> C:\haoka\server\uvicorn.err.log
