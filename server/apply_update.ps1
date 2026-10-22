# Runs on the cloud host. Unpacks haoka-update.zip over app code, never touches .env, then restarts the API task.
$ErrorActionPreference = "Continue"
$log = "C:\haoka\server\deploy.log"
function Log([string]$msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $msg
    Add-Content -Path $log -Value $line
    Write-Host $line
}

Log "apply_update begin"
$zip = "C:\Users\Administrator\haoka-update.zip"
$unpack = "C:\haoka\incoming\unpack"
if (Test-Path $zip) {
    if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $unpack | Out-Null
    Expand-Archive -Path $zip -DestinationPath $unpack -Force
    $src = Join-Path $unpack "app"
    if (-not (Test-Path $src)) { $src = $unpack }
    Copy-Item (Join-Path $src "*.py") "C:\haoka\server\app\" -Force
    Log "code copied"
} else {
    Log "no zip, restart only"
}

$py = "C:\haoka\server\.venv\Scripts\python.exe"
Set-Location C:\haoka\server
& $py -c "import app.main" *> C:\haoka\server\import_err.txt
Log ("import_exit=" + $LASTEXITCODE)
if ($LASTEXITCODE -ne 0) {
    Get-Content C:\haoka\server\import_err.txt | ForEach-Object { Log $_ }
    exit 1
}

$action = New-ScheduledTaskAction -Execute "C:\haoka\server\start_api.bat" -WorkingDirectory "C:\haoka\server"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "HaokaUvicorn" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Log "task registered"
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "uvicorn" } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep 2
schtasks /End /TN HaokaUvicorn 2>&1 | Out-Null
Start-ScheduledTask -TaskName "HaokaUvicorn"
Start-Sleep 8
$listen = netstat -ano | findstr "LISTENING" | findstr ":443 "
Log ("listen=" + $listen)
if (Test-Path C:\haoka\server\uvicorn.err.log) {
    Get-Content C:\haoka\server\uvicorn.err.log -Tail 20 | ForEach-Object { Log $_ }
}
try {
    $hf = "C:\haoka\server\health_check.txt"
    Remove-Item $hf -Force -ErrorAction SilentlyContinue
    & $py -c "import ssl,urllib.request; ctx=ssl._create_unverified_context(); d=urllib.request.urlopen('https://127.0.0.1/health?format=json', context=ctx, timeout=10).read().decode('utf-8','replace'); open(r'C:\\haoka\\server\\health_check.txt','w',encoding='utf-8').write(d)"
    $health = Get-Content -Path $hf -Raw -Encoding UTF8
    Log ("health=" + $health.Trim())
    if ($health -notmatch '"ok"\s*:\s*true') { throw "health missing ok" }
} catch {
    Log ("health_fail=" + $_.Exception.Message)
    exit 1
}
Log "apply_update ok"
