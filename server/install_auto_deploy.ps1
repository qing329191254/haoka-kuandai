# Run once in Windows PowerShell on the cloud host (ecm-ed7c).
# Installs a portable Git if needed, clones the repo, and checks main every minute.
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Save-Zip([string]$Destination, [string[]]$Urls) {
    if (Test-Path $Destination) { Remove-Item $Destination -Force }
    foreach ($url in $Urls) {
        Write-Host "get $url"
        & curl.exe -L --connect-timeout 20 --retry 2 --retry-delay 2 -o $Destination $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Destination) -and (Get-Item $Destination).Length -gt 1MB) {
            return
        }
        Write-Host "failed $url"
        if (Test-Path $Destination) { Remove-Item $Destination -Force -ErrorAction SilentlyContinue }
    }
    throw "download failed: $Destination"
}
$NodeVersion = "v24.22.0"
$NodeZipName = "node-v24.22.0-win-x64.zip"
$GitExe = "C:\haoka\git\cmd\git.exe"
$Repo = "C:\haoka\repo"
$RepoUrl = "https://github.com/qing329191254/haoka-kuandai.git"

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

if (-not (Test-Path "C:\haoka\server\.venv\Scripts\python.exe")) {
    throw "C:\haoka\server\.venv not found. Run this on the cloud host, not on a dev PC."
}

$git = Find-Git
if (-not $git) {
    Write-Host "downloading Git"
    New-Item -ItemType Directory -Force -Path C:\haoka | Out-Null
    $zip = "C:\haoka\MinGit.zip"
    Save-Zip $zip @(
        "https://mirrors.huaweicloud.com/git-for-windows/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip",
        "https://cdn.npmmirror.com/binaries/git-for-windows/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip"
    )
    if (Test-Path "C:\haoka\git") { Remove-Item "C:\haoka\git" -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath "C:\haoka\git" -Force
    Remove-Item $zip -Force
    $git = $GitExe
}
if (-not (Test-Path $git)) { throw "git install failed" }

$npm = "C:\haoka\node\npm.cmd"
if (-not (Test-Path $npm) -and -not (Test-Path "C:\Program Files\nodejs\npm.cmd")) {
    Write-Host "downloading Node.js"
    $zip = "C:\haoka\$NodeZipName"
    Save-Zip $zip @(
        "https://cdn.npmmirror.com/binaries/node/$NodeVersion/$NodeZipName",
        "https://npmmirror.com/mirrors/node/$NodeVersion/$NodeZipName"
    )
    $unpack = "C:\haoka\node-unpack"
    if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $unpack -Force
    $inner = Get-ChildItem $unpack -Directory | Select-Object -First 1
    if (Test-Path "C:\haoka\node") { Remove-Item "C:\haoka\node" -Recurse -Force }
    Move-Item $inner.FullName "C:\haoka\node"
    Remove-Item $unpack -Recurse -Force
    Remove-Item $zip -Force
}
if (-not (Test-Path $npm) -and -not (Test-Path "C:\Program Files\nodejs\npm.cmd")) {
    throw "node install failed"
}

$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE = "Never"
if (-not (Test-Path (Join-Path $Repo ".git"))) {
    Write-Host "cloning repo"
    & $git -c "safe.directory=*" clone --branch main --single-branch $RepoUrl $Repo
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
} else {
    & $git -c "safe.directory=*" -C $Repo fetch origin main
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
    & $git -c "safe.directory=*" -C $Repo reset --hard origin/main
    if ($LASTEXITCODE -ne 0) { throw "git reset failed" }
}

foreach ($aclPath in @("C:\haoka\git", "C:\haoka\node", "C:\haoka\repo")) {
    if (Test-Path $aclPath) { icacls $aclPath /grant "*S-1-5-18:(OI)(CI)F" /T | Out-Null }
}
icacls C:\haoka\server /grant "*S-1-5-18:(OI)(CI)M" /T | Out-Null

$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$tr = "`"$powershell`" -NoProfile -ExecutionPolicy Bypass -File C:\haoka\repo\server\auto_deploy.ps1"
schtasks /Create /F /TN HaokaAutoDeploy /SC MINUTE /MO 1 /RU SYSTEM /RL HIGHEST /TR $tr
if ($LASTEXITCODE -ne 0) { throw "failed to register HaokaAutoDeploy" }

try {
    $task = Get-ScheduledTask -TaskName HaokaAutoDeploy
    $task.Settings.ExecutionTimeLimit = "PT45M"
    $task.Settings.StartWhenAvailable = $true
    Set-ScheduledTask -InputObject $task | Out-Null
} catch {
    Write-Host "task registered; extra settings were left at defaults"
}

Write-Host "HaokaAutoDeploy registered. Running the first deploy."
& $powershell -NoProfile -ExecutionPolicy Bypass -File "C:\haoka\repo\server\auto_deploy.ps1" -Force
if ($LASTEXITCODE -ne 0) { throw "first deploy failed, see C:\haoka\server\deploy.log" }
Write-Host "auto deploy is on. Pushes to main update this host within a minute."
