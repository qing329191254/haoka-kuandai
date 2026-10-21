# Cloud host only. Pulls main and updates the running API.
# Never reads or writes C:\haoka\server\.env.
param([switch]$Force)

$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoUrl = "https://github.com/qing329191254/haoka-kuandai.git"
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
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    Write-Host $line
    Set-Content -Path $StatusPath -Value $line -Encoding UTF8
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

function Sync-Tree([string]$Source, [string]$Destination) {
    & robocopy $Source $Destination /MIR /NFL /NDL /NJH /NJS /nc /ns /np /XD __pycache__ /XF *.pyc
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
    $global:LASTEXITCODE = 0
}

function Ensure-ApiTask {
    $existing = Get-ScheduledTask -TaskName "HaokaUvicorn" -ErrorAction SilentlyContinue
    if ($existing) { return }
    $action = New-ScheduledTaskAction -Execute (Join-Path $AppRoot "start_api.bat") -WorkingDirectory $AppRoot
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "HaokaUvicorn" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Log "registered HaokaUvicorn"
}

function Restart-Api {
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "uvicorn" } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
    schtasks /End /TN HaokaUvicorn 2>&1 | Out-Null
    Start-ScheduledTask -TaskName "HaokaUvicorn"
}

function Wait-Health {
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 2
        try {
            $health = & $Python -c "import ssl,urllib.request; ctx=ssl._create_unverified_context(); print(urllib.request.urlopen('https://127.0.0.1/health', context=ctx, timeout=8).read().decode())"
            if ($health -match '"ok"\s*:\s*true') { return $health.Trim() }
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

function Update-Admin([string]$RemoteSha) {
    $npm = "C:\Program Files\nodejs\npm.cmd"
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

if (Test-Path $LockPath) {
    $age = (Get-Date) - (Get-Item $LockPath).LastWriteTime
    if ($age.TotalMinutes -lt 20) { exit 0 }
}
New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
Set-Content -Path $LockPath -Value (Get-Date -Format o) -Encoding ASCII

try {
    $script:Git = Find-Git
    if (-not $script:Git) { throw "git not found. Run server\install_auto_deploy.ps1 once on the cloud host." }

    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "Never"

    if (-not (Test-Path (Join-Path $Repo ".git"))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Repo) | Out-Null
        Write-Log "cloning $RepoUrl"
        Invoke-Git @("clone", "--branch", "main", "--single-branch", $RepoUrl, $Repo)
    }

    Write-Log "fetch origin/main"
    Invoke-Git @("-C", $Repo, "fetch", "origin", "main")
    Invoke-Git @("-C", $Repo, "reset", "--hard", "origin/main")
    $remoteSha = (& $script:Git -c "safe.directory=*" -C $Repo rev-parse "HEAD").Trim()
    if ($LASTEXITCODE -ne 0 -or -not $remoteSha) { throw "cannot read HEAD" }

    $previousSha = ""
    if (Test-Path $ApiShaPath) { $previousSha = (Get-Content -Path $ApiShaPath -Raw).Trim() }

    $apiChanged = $Force -or -not $previousSha
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
