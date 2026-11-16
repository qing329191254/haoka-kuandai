# Cloud host only. Detects uvicorn "zombie" (process alive but :443 /health dead)
# and restarts HaokaUvicorn. Safe to run every 1-2 minutes via scheduled task.
# Skips while auto_deploy.lock is held. ASCII-safe for Windows PowerShell 5.1.
$ErrorActionPreference = "Continue"

$AppRoot = "C:\haoka\server"
$Python = Join-Path $AppRoot ".venv\Scripts\python.exe"
$LockPath = Join-Path $AppRoot "auto_deploy.lock"
$LogPath = Join-Path $AppRoot "watchdog.log"
$CooldownPath = Join-Path $AppRoot "watchdog_last_restart.txt"
$HealthFile = Join-Path $AppRoot "watchdog_health.txt"
$CooldownSeconds = 180

function Write-WatchLog([string]$Message) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $Message
    New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($LogPath, $line + [Environment]::NewLine, $utf8)
    Write-Host $line
}

function Test-DeployBusy {
    if (-not (Test-Path $LockPath)) { return $false }
    $raw = (Get-Content -Path $LockPath -ErrorAction SilentlyContinue | Select-Object -First 1)
    $lockPid = 0
    if (-not [int]::TryParse("$raw", [ref]$lockPid)) {
        Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
        return $false
    }
    if (Get-Process -Id $lockPid -ErrorAction SilentlyContinue) { return $true }
    Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
    return $false
}

function Test-ApiHealthy {
    if (-not (Test-Path $Python)) {
        Write-WatchLog "python missing: $Python"
        return $false
    }
    $listen = Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue
    if (-not $listen) {
        Write-WatchLog "443 not listening"
        return $false
    }
    try {
        Remove-Item $HealthFile -Force -ErrorAction SilentlyContinue
        & $Python -c @"
import ssl, urllib.request
ctx = ssl._create_unverified_context()
data = urllib.request.urlopen('https://127.0.0.1/health?format=json', context=ctx, timeout=10).read().decode('utf-8', 'replace')
open(r'$($HealthFile.Replace('\','\\'))', 'w', encoding='utf-8').write(data)
"@
        if (-not (Test-Path $HealthFile)) { return $false }
        $health = Get-Content -Path $HealthFile -Raw -Encoding UTF8
        if ($health -match '"ok"\s*:\s*true') { return $true }
        Write-WatchLog ("health bad: " + $health.Trim())
        return $false
    } catch {
        Write-WatchLog ("health error: " + $_.Exception.Message)
        return $false
    }
}

function Test-CooldownActive {
    if (-not (Test-Path $CooldownPath)) { return $false }
    try {
        $raw = (Get-Content -Path $CooldownPath -Raw).Trim()
        $last = [DateTime]::Parse($raw)
        $age = (Get-Date) - $last
        return ($age.TotalSeconds -lt $CooldownSeconds)
    } catch {
        return $false
    }
}

function Restart-ApiFromWatchdog {
    Write-WatchLog "restart begin"
    schtasks /End /TN HaokaUvicorn 2>&1 | Out-Null
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and ($_.CommandLine -match "uvicorn") } |
        ForEach-Object {
            Write-WatchLog ("stop pid=" + $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    Start-Sleep -Seconds 3
    Start-ScheduledTask -TaskName "HaokaUvicorn" -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 3
        if (Test-ApiHealthy) {
            Set-Content -Path $CooldownPath -Value ((Get-Date).ToString("o")) -Encoding ASCII
            Write-WatchLog "restart ok"
            return $true
        }
    }
    Set-Content -Path $CooldownPath -Value ((Get-Date).ToString("o")) -Encoding ASCII
    Write-WatchLog "restart failed: still unhealthy"
    return $false
}

if (Test-DeployBusy) {
    Write-WatchLog "skip: auto_deploy running"
    exit 0
}

if (Test-ApiHealthy) {
    # Trim log occasionally
    if (Test-Path $LogPath) {
        $length = (Get-Item $LogPath).Length
        if ($length -gt 256KB) {
            $tail = Get-Content $LogPath -Tail 200
            Set-Content -Path $LogPath -Value $tail -Encoding UTF8
        }
    }
    exit 0
}

# Double-check after short wait to avoid flapping during normal restart
Start-Sleep -Seconds 5
if (Test-DeployBusy) {
    Write-WatchLog "skip: auto_deploy running after wait"
    exit 0
}
if (Test-ApiHealthy) {
    Write-WatchLog "recovered without restart"
    exit 0
}

if (Test-CooldownActive) {
    Write-WatchLog "skip: cooldown after recent restart"
    exit 0
}

Restart-ApiFromWatchdog | Out-Null
