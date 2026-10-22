# Cloud host only. Pulls main and updates the running API.
# Never reads or writes C:\haoka\server\.env.
param([switch]$Force)

$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoUrls = @(
    "https://ghfast.top/https://github.com/qing329191254/haoka-kuandai.git",
    "https://gh-proxy.com/https://github.com/qing329191254/haoka-kuandai.git",
    "https://github.com/qing329191254/haoka-kuandai.git"
)
$Repo = "C:\haoka\repo"
$AppRoot = "C:\haoka\server"
$LogPath = Join-Path $AppRoot "deploy.log"
$LockPath = Join-Path $AppRoot "auto_deploy.lock"
$ApiShaPath = Join-Path $AppRoot "deployed_api.sha"
$AdminShaPath = Join-Path $AppRoot "deployed_admin.sha"
$StatusPath = Join-Path $AppRoot "deploy_status.txt"
$Python = Join-Path $AppRoot ".venv\Scripts\python.exe"

function Write-Log([string]$Message) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $Message
    New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
    # utf8NoBOM，避免 status 带 BOM 导致 /health JSON 在 GBK 控制台无法打印
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($LogPath, $line + [Environment]::NewLine, $utf8)
    Write-Host $line
    [System.IO.File]::WriteAllText($StatusPath, $line, $utf8)
}

function Find-Git {
    foreach ($candidate in @(
        "C:\haoka\git\cmd\git.exe",
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe"
    )) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Invoke-Git {
    param([string[]]$GitArgs)
    & $script:Git -c "safe.directory=*" @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("git failed: " + ($GitArgs -join " "))
    }
}

function Update-Origin {
    foreach ($url in $RepoUrls) {
        & $script:Git -c "safe.directory=*" -C $Repo remote set-url origin $url
        & $script:Git -c "safe.directory=*" -c http.version=HTTP/1.1 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 -C $Repo fetch origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Log "fetched $url"
            return
        }
        Write-Log "fetch failed $url"
    }
    throw "git fetch failed"
}

function Sync-Tree([string]$Source, [string]$Destination) {
    & robocopy $Source $Destination /MIR /NFL /NDL /NJH /NJS /nc /ns /np /XD __pycache__ /XF *.pyc
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
    $global:LASTEXITCODE = 0
}

function Remove-LeftoverApiTasks {
    # 历史手动任务（如 HaokaUvicornOnce → start_haoka_uvicorn.bat）会重复拉起 API
    foreach ($tn in @("HaokaUvicornOnce", "HaokaApi", "HaokaUvicornOld")) {
        $t = Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
        if ($t) {
            Disable-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue | Out-Null
            Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "removed leftover task $tn"
        }
    }
}

function Ensure-ApiTask {
    Remove-LeftoverApiTasks
    $bat = Join-Path $AppRoot "start_api.bat"
    $existing = Get-ScheduledTask -TaskName "HaokaUvicorn" -ErrorAction SilentlyContinue
    if ($existing -and $existing.Actions.Count -gt 0 -and $existing.Actions[0].Execute -eq $bat) {
        return
    }
    $action = New-ScheduledTaskAction -Execute $bat -WorkingDirectory $AppRoot
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName "HaokaUvicorn" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "HaokaUvicorn uses $bat"
}

function Test-PortFree([int]$Port) {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return -not $listeners
}

function Stop-AllUvicorn {
    # 停计划任务后结束所有 uvicorn 相关进程（含 Windows venv 启动器与基座解释器）
    schtasks /End /TN HaokaUvicorn 2>&1 | Out-Null
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and ($_.CommandLine -match "uvicorn") } |
        ForEach-Object {
            Write-Log ("stop uvicorn pid=" + $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-PortFree 443) { return }
        Start-Sleep -Seconds 1
    }
    Write-Log "warn: port 443 still busy after stop"
}

function Restart-Api {
    # 重要（Windows）：.venv\Scripts\python.exe 是启动器，会再拉起
    # C:\Program Files\Python312\python.exe 作为子进程跑同一条 uvicorn 命令。
    # 这是正常现象，不是两个服务抢端口。切勿在启动后按路径杀掉 Python312 子进程，
    # 否则会把真正的工作进程杀掉，导致 health 失败并回滚。
    Remove-LeftoverApiTasks
    Stop-AllUvicorn
    Start-Sleep -Seconds 1
    Start-ScheduledTask -TaskName "HaokaUvicorn"
    # 等进程起来并开始监听
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        $listen = Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue
        if ($listen) {
            Write-Log ("api listening on 443 owners=" + (($listen | Select-Object -ExpandProperty OwningProcess -Unique) -join ","))
            return
        }
    }
    Write-Log "warn: api not listening on 443 yet, Wait-Health will retry"
}

function Wait-Health {
    # 重启 uvicorn/SSL 有时要半分钟以上；结果写入文件避免 Windows GBK 控制台 print 非 ASCII 失败
    $outFile = Join-Path $AppRoot "health_check.txt"
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 3
        try {
            Remove-Item $outFile -Force -ErrorAction SilentlyContinue
            & $Python -c @"
import ssl, urllib.request
ctx = ssl._create_unverified_context()
data = urllib.request.urlopen('https://127.0.0.1/health?format=json', context=ctx, timeout=10).read().decode('utf-8', 'replace')
open(r'$($outFile.Replace('\','\\'))', 'w', encoding='utf-8').write(data)
"@
            if (Test-Path $outFile) {
                $health = Get-Content -Path $outFile -Raw -Encoding UTF8
                if ($health -match '"ok"\s*:\s*true') { return $health.Trim() }
            }
        } catch {
            continue
        }
    }
    return $null
}

function Restore-App([string]$Backup) {
    if (-not (Test-Path $Backup)) { return }
    $dest = Join-Path $AppRoot "app"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $Backup $dest -Recurse -Force
}

function Find-Npm {
    foreach ($candidate in @(
        "C:\haoka\node\npm.cmd",
        "C:\Program Files\nodejs\npm.cmd"
    )) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Update-Admin([string]$RemoteSha) {
    $npm = Find-Npm
    if (-not (Test-Path $AdminShaPath)) {
        Set-Content -Path $AdminShaPath -Value $RemoteSha -Encoding ASCII
        Write-Log "keep existing admin_dist until admin source changes"
        return
    }
    $previous = (Get-Content -Path $AdminShaPath -Raw).Trim()
    if ($previous -eq $RemoteSha) { return }
    $names = & $script:Git -c "safe.directory=*" -C $Repo diff --name-only $previous $RemoteSha -- admin
    if ($LASTEXITCODE -ne 0) { throw "cannot diff admin" }
    if (-not $names) {
        Set-Content -Path $AdminShaPath -Value $RemoteSha -Encoding ASCII
        return
    }
    if (-not (Test-Path $npm)) {
        Write-Log "admin source changed, Node.js is not installed, admin_dist left as-is"
        return
    }
    Write-Log "building admin"
    $env:NPM_CONFIG_CACHE = "C:\haoka\npm-cache"
    $nodeDir = Split-Path $npm -Parent
    $env:PATH = $nodeDir + ";" + $env:PATH
    Push-Location (Join-Path $Repo "admin")
    try {
        Remove-Item Env:VITE_API_BASE -ErrorAction SilentlyContinue
        & $npm ci
        if ($LASTEXITCODE -ne 0) {
            & $npm ci --registry https://registry.npmmirror.com
        }
        if ($LASTEXITCODE -ne 0) { throw "npm ci failed" }
        & $npm run build
        if ($LASTEXITCODE -ne 0) { throw "admin build failed" }
    } finally {
        Pop-Location
    }
    $dist = Join-Path $Repo "admin\dist"
    if (-not (Test-Path (Join-Path $dist "index.html"))) { throw "admin dist missing index.html" }
    Sync-Tree $dist (Join-Path $AppRoot "admin_dist")
    Set-Content -Path $AdminShaPath -Value $RemoteSha -Encoding ASCII
    Write-Log "admin_dist updated"
}

if (-not (Test-Path $Python)) {
    Write-Host "stop: cloud venv not found at $Python"
    exit 1
}

function Test-DeployLockHeld {
    if (-not (Test-Path $LockPath)) { return $false }
    $ownerText = ""
    try { $ownerText = (Get-Content -Path $LockPath -Raw).Trim() } catch { return $true }
    if ($ownerText -notmatch '^\d+$') { return $true }
    $owner = Get-Process -Id ([int]$ownerText) -ErrorAction SilentlyContinue
    if (-not $owner) { return $false }
    return $owner.ProcessName -match 'powershell|pwsh'
}

if (Test-DeployLockHeld) {
    Write-Host "deploy already running; a newer push waits until this round finishes"
    exit 0
}
New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
Set-Content -Path $LockPath -Value $PID -Encoding ASCII

try {
    $script:Git = Find-Git
    if (-not $script:Git) { throw "git not found. Run server\install_auto_deploy.ps1 once on the cloud host." }

    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "Never"

    if (-not (Test-Path (Join-Path $Repo ".git"))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Repo) | Out-Null
        if (Test-Path $Repo) { Remove-Item $Repo -Recurse -Force }
        $cloned = $false
        foreach ($url in $RepoUrls) {
            Write-Log "cloning $url"
            & $script:Git -c "safe.directory=*" -c http.version=HTTP/1.1 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 clone --branch main --single-branch $url $Repo
            if ($LASTEXITCODE -eq 0) { $cloned = $true; break }
            if (Test-Path $Repo) { Remove-Item $Repo -Recurse -Force }
        }
        if (-not $cloned) { throw "git clone failed" }
    }

    Ensure-ApiTask
    $rounds = 0
    while ($rounds -lt 3) {
    $rounds++
    Update-Origin
    Invoke-Git @("-C", $Repo, "reset", "--hard", "origin/main")
    $remoteSha = (& $script:Git -c "safe.directory=*" -C $Repo rev-parse "HEAD").Trim()
    if ($LASTEXITCODE -ne 0 -or -not $remoteSha) { throw "cannot read HEAD" }

    $previousSha = ""
    if (Test-Path $ApiShaPath) { $previousSha = (Get-Content -Path $ApiShaPath -Raw).Trim() }

    $apiChanged = ($Force -and $rounds -eq 1) -or -not $previousSha
    if (-not $apiChanged -and $previousSha -ne $remoteSha) {
        $names = & $script:Git -c "safe.directory=*" -C $Repo diff --name-only $previousSha $remoteSha -- server/app server/requirements.txt server/start_api.bat
        if ($LASTEXITCODE -ne 0) { throw "cannot diff api" }
        $apiChanged = [bool]$names
    }

    if (-not $apiChanged -and $previousSha -eq $remoteSha) {
        Write-Log "api up to date $remoteSha"
    } elseif (-not $apiChanged) {
        Set-Content -Path $ApiShaPath -Value $remoteSha -Encoding ASCII
        Write-Log "no api changes in $remoteSha"
    } else {
        Write-Log "deploy api $remoteSha"
        $backup = "C:\haoka\incoming\app.bak"
        New-Item -ItemType Directory -Force -Path "C:\haoka\incoming" | Out-Null
        if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
        Copy-Item (Join-Path $AppRoot "app") $backup -Recurse -Force

        $reqPath = Join-Path $AppRoot "requirements.txt"
        $reqBackup = Join-Path $AppRoot "requirements.txt.bak"
        $oldReq = ""
        if (Test-Path $reqPath) {
            Copy-Item $reqPath $reqBackup -Force
            $oldReq = (Get-FileHash $reqPath -Algorithm SHA256).Hash
        }

        Sync-Tree (Join-Path $Repo "server\app") (Join-Path $AppRoot "app")
        Copy-Item (Join-Path $Repo "server\requirements.txt") $reqPath -Force
        Copy-Item (Join-Path $Repo "server\start_api.bat") (Join-Path $AppRoot "start_api.bat") -Force

        $newReq = (Get-FileHash $reqPath -Algorithm SHA256).Hash
        if ($newReq -ne $oldReq) {
            Write-Log "pip install"
            & $Python -m pip install -r $reqPath
            if ($LASTEXITCODE -ne 0) {
                & $Python -m pip install -r $reqPath -i https://pypi.tuna.tsinghua.edu.cn/simple
            }
            if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
        }

        Set-Location $AppRoot
        $prefix = (& $Python -c "import sys; print(sys.prefix)").Trim()
        if ($prefix.ToLower() -notlike "c:\haoka\server\.venv*") {
            throw "refusing system python, prefix=$prefix"
        }
        Write-Log "venv python $prefix"
        & $Python -c "import app.main" > (Join-Path $AppRoot "import_err.txt") 2>&1
        if ($LASTEXITCODE -ne 0) {
            Restore-App $backup
            if (Test-Path $reqBackup) { Copy-Item $reqBackup $reqPath -Force }
            $detail = ""
            if (Test-Path (Join-Path $AppRoot "import_err.txt")) {
                $detail = (Get-Content (Join-Path $AppRoot "import_err.txt") -Raw)
            }
            throw ("import failed, previous code restored. " + $detail)
        }

        Ensure-ApiTask
        Restart-Api
        $health = Wait-Health
        if (-not $health) {
            Write-Log "health failed, restoring previous code"
            Restore-App $backup
            if (Test-Path $reqBackup) { Copy-Item $reqBackup $reqPath -Force }
            Restart-Api
            $restored = Wait-Health
            if ($restored) { throw "new code failed health check, previous code restored" }
            throw "new code failed health check and rollback did not recover"
        }
        Set-Content -Path $ApiShaPath -Value $remoteSha -Encoding ASCII
        Write-Log ("api healthy " + $health)
    }

    try {
        Update-Admin $remoteSha
    } catch {
        Write-Log ("admin_fail=" + $_.Exception.Message)
    }

    Update-Origin
    $latestSha = (& $script:Git -c "safe.directory=*" -C $Repo rev-parse "origin/main").Trim()
    if ($LASTEXITCODE -ne 0 -or -not $latestSha) { throw "cannot read origin/main" }
    if ($latestSha -eq $remoteSha) { break }
    Write-Log "newer commit arrived during deploy, run again"
    }
} catch {
    Write-Log ("deploy_fail=" + $_.Exception.Message)
    exit 1
} finally {
    Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
    if (Test-Path $LogPath) {
        $length = (Get-Item $LogPath).Length
        if ($length -gt 512KB) {
            $tail = Get-Content $LogPath -Tail 400
            Set-Content -Path $LogPath -Value $tail -Encoding UTF8
        }
    }
}
