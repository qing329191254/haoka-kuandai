# 一次性修复：去掉错误的「双 uvicorn」误判，禁用遗留任务，只保留 HaokaUvicorn(venv)。
# 在云主机以管理员 PowerShell 执行：
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\haoka\repo\server\repair_api_runtime.ps1
$ErrorActionPreference = "Continue"
$AppRoot = "C:\haoka\server"
$Bat = Join-Path $AppRoot "start_api.bat"
$Log = Join-Path $AppRoot "deploy.log"

function Log([string]$msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $msg
    Add-Content -Path $Log -Value $line -Encoding UTF8
    Write-Host $line
}

Log "repair_api_runtime begin"

# 1) 停掉自动部署，避免修复过程中又回滚
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -match "auto_deploy") } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
schtasks /End /TN HaokaAutoDeploy 2>&1 | Out-Null

# 2) 删除/禁用会抢端口或重复启动的遗留任务
foreach ($tn in @("HaokaUvicornOnce", "HaokaApi", "HaokaUvicornOld")) {
    $t = Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
    if ($t) {
        Disable-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue | Out-Null
        Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue
        Log "removed leftover task $tn"
    }
}

# 3) 确保正式任务指向 start_api.bat（venv）
$action = New-ScheduledTaskAction -Execute $Bat -WorkingDirectory $AppRoot
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "HaokaUvicorn" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Log "HaokaUvicorn -> $Bat"

# 4) 停干净后重启（Windows venv 会出现「启动器 + 基座解释器」两个 PID，属正常，不要杀 Python312 子进程）
schtasks /End /TN HaokaUvicorn 2>&1 | Out-Null
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -match "uvicorn") } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3
Start-ScheduledTask -TaskName "HaokaUvicorn"
Start-Sleep -Seconds 8

$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -match "uvicorn") }
Log ("uvicorn_pids=" + (($procs | ForEach-Object { $_.ProcessId }) -join ","))
$listen = Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue
Log ("listen_443_count=" + @($listen).Count + " owners=" + (($listen | Select-Object -ExpandProperty OwningProcess -Unique) -join ","))

$py = Join-Path $AppRoot ".venv\Scripts\python.exe"
$healthFile = Join-Path $AppRoot "health_check.txt"
try {
    Remove-Item $healthFile -Force -ErrorAction SilentlyContinue
    & $py -c @"
import ssl, urllib.request
ctx = ssl._create_unverified_context()
data = urllib.request.urlopen('https://127.0.0.1/health?format=json', context=ctx, timeout=15).read().decode('utf-8', 'replace')
open(r'$($healthFile.Replace('\','\\'))', 'w', encoding='utf-8').write(data)
"@
    if (Test-Path $healthFile) {
        $health = Get-Content -Path $healthFile -Raw -Encoding UTF8
        Log ("health=" + $health.Trim())
    } else {
        Log "health_fail=no output file"
    }
} catch {
    Log ("health_fail=" + $_.Exception.Message)
}

# 5) 重新打开自动部署（下一分钟会跑；也可手动 -Force）
schtasks /Run /TN HaokaAutoDeploy 2>&1 | Out-Null
Log "repair_api_runtime done. Note: 2 uvicorn PIDs (venv launcher -> Python312) on Windows is NORMAL; only listen count on :443 matters."
