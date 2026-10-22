@echo off
cd /d C:\haoka\server
set "VIRTUAL_ENV=C:\haoka\server\.venv"
set "PATH=C:\haoka\server\.venv\Scripts;%PATH%"
REM 改用 wsproto 实现，并关闭 permessage-deflate（websockets+SSL 在部分 Windows 上会出现 101 后无下行）
"C:\haoka\server\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 443 --ssl-certfile "C:\certs\www.lcnh-platform.cn.pem" --ssl-keyfile "C:\certs\www.lcnh-platform.cn.key" --ws wsproto --ws-per-message-deflate=false > C:\haoka\server\uvicorn.out.log 2> C:\haoka\server\uvicorn.err.log
