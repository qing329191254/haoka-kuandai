@echo off
cd /d C:\haoka\server
set "VIRTUAL_ENV=C:\haoka\server\.venv"
set "PATH=C:\haoka\server\.venv\Scripts;%PATH%"
REM Windows 上 .venv\Scripts\python.exe 是启动器，进程列表里常会再看到
REM C:\Program Files\Python312\python.exe 子进程（同一条 uvicorn 命令）——这是正常的，
REM 不是两个服务。判断是否异常请看 443 端口监听数量，而不是 python 路径数量。
"C:\haoka\server\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 443 --ssl-certfile "C:\certs\www.lcnh-platform.cn.pem" --ssl-keyfile "C:\certs\www.lcnh-platform.cn.key" > C:\haoka\server\uvicorn.out.log 2> C:\haoka\server\uvicorn.err.log
