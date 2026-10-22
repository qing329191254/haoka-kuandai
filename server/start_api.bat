@echo off
cd /d C:\haoka\server
REM 不要加实验性 WS 参数：参数解析失败会导致进程起不来，auto_deploy 健康检查失败后回滚，/health 就会「闪一下又变旧」。
"C:\haoka\server\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 443 --ssl-certfile "C:\certs\www.lcnh-platform.cn.pem" --ssl-keyfile "C:\certs\www.lcnh-platform.cn.key" > C:\haoka\server\uvicorn.out.log 2> C:\haoka\server\uvicorn.err.log
