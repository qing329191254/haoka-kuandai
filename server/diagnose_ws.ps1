# 在云主机排查 WSS 为什么没下行。管理员 PowerShell：
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\haoka\repo\server\diagnose_ws.ps1
$ErrorActionPreference = "Continue"
$AppRoot = "C:\haoka\server"
$Py = Join-Path $AppRoot ".venv\Scripts\python.exe"
$Out = Join-Path $AppRoot "ws_diagnose.txt"

function Log([string]$m) {
    $line = (Get-Date -Format "HH:mm:ss") + " " + $m
    Add-Content -Path $Out -Value $line -Encoding UTF8
    Write-Host $line
}

Remove-Item $Out -Force -ErrorAction SilentlyContinue
Log "=== WS diagnose begin ==="

Log "--- listen 443 ---"
Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object { Log ("pid=" + $_.OwningProcess) }

Log "--- uvicorn processes ---"
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "uvicorn" } |
    ForEach-Object { Log ("pid=" + $_.ProcessId + " " + $_.CommandLine) }

Log "--- last cs_ws_debug ---"
if (Test-Path (Join-Path $AppRoot "cs_ws_debug.log")) {
    Get-Content (Join-Path $AppRoot "cs_ws_debug.log") -Tail 20 | ForEach-Object { Log $_ }
} else {
    Log "(no cs_ws_debug.log yet — open App/admin CS once then re-run)"
}

Log "--- last uvicorn.err ---"
if (Test-Path (Join-Path $AppRoot "uvicorn.err.log")) {
    Get-Content (Join-Path $AppRoot "uvicorn.err.log") -Tail 30 | ForEach-Object { Log $_ }
}

Log "--- local wss echo test (127.0.0.1) ---"
& $Py -c @"
import asyncio, ssl, json, sys
try:
    import websockets
except ImportError:
    print('NO_WEBSOCKETS_LIB')
    sys.exit(2)

async def main():
    ctx = ssl._create_unverified_context()
    uri = 'wss://127.0.0.1/api/ws-echo'
    try:
        async with websockets.connect(uri, ssl=ctx, open_timeout=8) as ws:
            print('CONNECTED')
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=5)
                print('RECV=' + repr(msg))
            except asyncio.TimeoutError:
                print('TIMEOUT_NO_SERVER_FRAME')
            await ws.send('{\"type\":\"ping\"}')
            try:
                msg2 = await asyncio.wait_for(ws.recv(), timeout=5)
                print('ECHO=' + repr(msg2))
            except asyncio.TimeoutError:
                print('TIMEOUT_NO_ECHO')
    except Exception as e:
        print('FAIL=' + repr(e))

asyncio.run(main())
"@ 2>&1 | ForEach-Object { Log ("py: " + $_) }

Log "=== done. Full log: $Out ==="
Get-Content $Out -Encoding UTF8
