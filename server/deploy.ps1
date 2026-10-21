# One-command deploy from this PC to the cloud host.
# Packs server\app\*.py, uploads one zip, asks the server task to restart.
# Does not upload .env.
$ErrorActionPreference = "Stop"
$server = $PSScriptRoot
$remote = "Administrator@219.152.92.39"
$stage = Join-Path $env:TEMP "haoka-update-stage"
$zip = Join-Path $env:TEMP "haoka-update.zip"

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $stage "app") | Out-Null
Copy-Item (Join-Path $server "app\*.py") (Join-Path $stage "app\")
Copy-Item (Join-Path $server "apply_update.ps1") $stage
Copy-Item (Join-Path $server "start_api.bat") $stage
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip

Write-Host "upload zip"
scp -o BatchMode=yes -o ConnectTimeout=20 $zip ($remote + ":C:/Users/Administrator/haoka-update.zip")
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

$remoteCmd = @'
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force -Path C:\haoka\incoming | Out-Null
if (Test-Path C:\haoka\incoming\unpack) { Remove-Item C:\haoka\incoming\unpack -Recurse -Force }
Expand-Archive -Force C:\Users\Administrator\haoka-update.zip C:\haoka\incoming\unpack
Copy-Item C:\haoka\incoming\unpack\apply_update.ps1 C:\haoka\server\apply_update.ps1 -Force
Copy-Item C:\haoka\incoming\unpack\start_api.bat C:\haoka\server\start_api.bat -Force
powershell -NoProfile -ExecutionPolicy Bypass -File C:\haoka\server\apply_update.ps1
'@
$b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteCmd))
Write-Host "apply on server"
ssh -o BatchMode=yes -o ConnectTimeout=25 $remote ("powershell -NoProfile -EncodedCommand " + $b64)
if ($LASTEXITCODE -ne 0) { throw "remote apply failed" }
Write-Host "deploy done"
