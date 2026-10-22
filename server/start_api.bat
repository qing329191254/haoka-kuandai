@echo off
cd /d C:\haoka\server
set "VIRTUAL_ENV=C:\haoka\server\.venv"
set "PATH=C:\haoka\server\.venv\Scripts;%PATH%"
REM 关闭 permessage-deflate：部分环境下握手 101 后下行帧异常，DevTools 消息为空。
"C:\haoka\server\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 443 --ssl-certfile "C:\certs\www.lcnh-platform.cn.pem" --ssl-keyfile "C:\certs\www.lcnh-platform.cn.key" --ws websockets --ws-per-message-deflate=false > C:\haoka\server\uvicorn.out.log 2> C:\haoka\server\uvicorn.err.log
