# Run once in Windows PowerShell on the cloud host (ecm-ed7c).
# Installs a portable Git if needed, clones the repo, and checks main every minute.
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$GitZip = "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip"
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
    Invoke-WebRequest -Uri $GitZip -OutFile $zip
    if (Test-Path "C:\haoka\git") { Remove-Item "C:\haoka\git" -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath "C:\haoka\git" -Force
    Remove-Item $zip -Force
    $git = $GitExe
}
if (-not (Test-Path $git)) { throw "git install failed" }

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

foreach ($aclPath in @("C:\haoka\git", "C:\haoka\repo")) {
    if (Test-Path $aclPath) { icacls $aclPath /grant "*S-1-5-18:(OI)(CI)F" /T | Out-Null }
}
icacls C:\haoka\server /grant "*S-1-5-18:(OI)(CI)M" /T | Out-Null

$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$tr = "`"$powershell`" -NoProfile -ExecutionPolicy Bypass -File C:\haoka\repo\server\auto_deploy.ps1"
schtasks /Create /F /TN HaokaAutoDeploy /SC MINUTE /MO 1 /RU SYSTEM /RL HIGHEST /TR $tr
if ($LASTEXITCODE -ne 0) { throw "failed to register HaokaAutoDeploy" }

try {
    $task = Get-ScheduledTask -TaskName HaokaAutoDeploy
    $task.Settings.ExecutionTimeLimit = "PT20M"
    $task.Settings.StartWhenAvailable = $true
    Set-ScheduledTask -InputObject $task | Out-Null
} catch {
    Write-Host "task registered; extra settings were left at defaults"
}

Write-Host "HaokaAutoDeploy registered. Running the first deploy."
& $powershell -NoProfile -ExecutionPolicy Bypass -File "C:\haoka\repo\server\auto_deploy.ps1" -Force
if ($LASTEXITCODE -ne 0) { throw "first deploy failed, see C:\haoka\server\deploy.log" }
Write-Host "auto deploy is on. Pushes to main update this host within a minute."
