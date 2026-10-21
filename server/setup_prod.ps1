# SETUP_PROD_V4 — first-time cloud bootstrap only (MySQL/venv/etc).
# Current production API is start_api.bat on :443 + HTTPS (HaokaUvicorn / auto_deploy).
# Do not treat the :8888 snippets below as live config.
# Run on the cloud host: powershell -ExecutionPolicy Bypass -File setup_prod.ps1
# ASCII-only so Windows PowerShell 5.1 (GBK) can parse it.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Test-Port([int]$Port) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", $Port)
        $c.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Find-MysqlExe {
    $candidates = @(
        "C:\mysql\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command mysql -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    return $null
}

function Install-LocalMysql {
    $basedir = "C:\mysql"
    $zip = Join-Path $env:TEMP "mysql-winx64.zip"
    $urls = @(
        "https://mirrors.sohu.com/mysql/MySQL-8.0/mysql-8.0.28-winx64.zip",
        "https://mirrors.ustc.edu.cn/mysql-ftp/Downloads/MySQL-8.0/mysql-8.0.28-winx64.zip",
        "https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-8.0.28-winx64.zip"
    )

    if (-not (Test-Path (Join-Path $basedir "bin\mysqld.exe"))) {
        Write-Host "==> Download MySQL 8 (bind 127.0.0.1:3306 only)"
        $ok = $false
        if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 50MB)) {
            Write-Host "    using existing zip"
            $ok = $true
        }
        else {
            foreach ($url in $urls) {
                try {
                    Write-Host ("    GET " + $url)
                    & curl.exe -L --progress-bar -o $zip $url
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $zip) -and ((Get-Item $zip).Length -gt 50MB)) {
                        $ok = $true
                        break
                    }
                }
                catch {
                    Write-Host ("    fail: " + $_.Exception.Message)
                }
            }
        }
        if (-not $ok) {
            throw "MySQL zip download failed. Check outbound network."
        }
        Write-Host "==> Extract to C:\mysql"
        if (Test-Path $basedir) { Remove-Item $basedir -Recurse -Force }
        $unpack = Join-Path $env:TEMP "mysql-unpack"
        if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $unpack -Force
        $inner = Get-ChildItem $unpack -Directory | Select-Object -First 1
        Move-Item $inner.FullName $basedir
        Remove-Item $unpack -Recurse -Force -ErrorAction SilentlyContinue
    }

    $iniLines = @(
        "[mysqld]",
        "basedir=C:/mysql",
        "datadir=C:/mysql/data",
        "port=3306",
        "character-set-server=utf8mb4",
        "collation-server=utf8mb4_unicode_ci",
        "bind-address=127.0.0.1"
    )
    Set-Content -Path (Join-Path $basedir "my.ini") -Value $iniLines -Encoding ASCII

    if (-not (Test-Path "C:\mysql\data\mysql")) {
        Write-Host "==> Initialize datadir"
        & (Join-Path $basedir "bin\mysqld.exe") --defaults-file=C:\mysql\my.ini --initialize-insecure
        if ($LASTEXITCODE -ne 0) {
            throw "mysqld --initialize-insecure failed. Install VC++ Redistributable x64 and retry."
        }
    }

    $svc = Get-Service -Name "MySQL" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "==> Install Windows service MySQL"
        & (Join-Path $basedir "bin\mysqld.exe") --install MySQL --defaults-file=C:\mysql\my.ini
    }
    Start-Service MySQL
    $deadline = (Get-Date).AddMinutes(2)
    while (-not (Test-Port 3306)) {
        if ((Get-Date) -gt $deadline) { throw "MySQL service started but port 3306 is not ready" }
        Start-Sleep -Seconds 2
    }
}

function Ensure-PaikebangDb {
    $mysql = Find-MysqlExe
    if (-not $mysql) { throw "mysql.exe not found" }
    $sqlFile = Join-Path $env:TEMP "init-paikebang.sql"
    $sqlLines = @(
        "CREATE DATABASE IF NOT EXISTS paikebang CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
        "CREATE USER IF NOT EXISTS 'paikebang'@'localhost' IDENTIFIED BY 'paikebang123';",
        "CREATE USER IF NOT EXISTS 'paikebang'@'127.0.0.1' IDENTIFIED BY 'paikebang123';",
        "GRANT ALL PRIVILEGES ON paikebang.* TO 'paikebang'@'localhost';",
        "GRANT ALL PRIVILEGES ON paikebang.* TO 'paikebang'@'127.0.0.1';",
        "FLUSH PRIVILEGES;"
    )
    Set-Content -Path $sqlFile -Value $sqlLines -Encoding ASCII
    $ok = $false
    $argSets = @(
        @("-u", "root"),
        @("-u", "root", "-proot"),
        @("-u", "paikebang", "-ppaikebang123")
    )
    foreach ($a in $argSets) {
        $all = $a + @("--default-character-set=utf8mb4")
        Get-Content $sqlFile | & $mysql @all
        if ($LASTEXITCODE -eq 0) { $ok = $true; break }
    }
    if (-not $ok) {
        throw "Cannot create database paikebang / user paikebang. Login as root and create them."
    }
    & $mysql -u paikebang -ppaikebang123 --database=paikebang -e "SELECT 1;"
    if ($LASTEXITCODE -ne 0) {
        throw "User paikebang cannot connect to database paikebang"
    }
}

function Install-Python {
    Write-Host "==> Install Python 3.12 (Add to PATH)"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $exe = Join-Path $env:TEMP "python-3.12.7-amd64.exe"
    $urls = @(
        "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe",
        "https://mirrors.huaweicloud.com/python/3.12.7/python-3.12.7-amd64.exe"
    )
    $ok = $false
    foreach ($url in $urls) {
        try {
            Write-Host ("    GET " + $url)
            Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
            $ok = $true
            break
        }
        catch {
            Write-Host ("    fail: " + $_.Exception.Message)
        }
    }
    if (-not $ok) { throw "Python installer download failed. Check outbound network." }
    $p = Start-Process -FilePath $exe -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_test=0" -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw ("Python installer exit code " + $p.ExitCode)
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Find-Python {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    foreach ($name in @("python", "py")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $p = $cmd.Path
            if (-not $p) { $p = [string]$cmd.Source }
            if ($p -and (Test-Path $p)) { return $p }
        }
    }
    $guess = @(
        "C:\Program Files\Python312\python.exe",
        "C:\Python312\python.exe"
    )
    foreach ($g in $guess) {
        if (Test-Path $g) { return $g }
    }
    return $null
}

if (-not (Test-Path (Join-Path $PSScriptRoot "admin_dist\index.html"))) {
    throw "Missing admin_dist\index.html"
}

$pyExe = Find-Python
if (-not $pyExe) {
    Install-Python
    $pyExe = Find-Python
}
if (-not $pyExe) {
    throw "Python not found after install. Open a new PowerShell and rerun setup_prod.ps1"
}

Write-Host "==> Free port 8888 (stop IIS sites bound to 8888)"
try {
    Import-Module WebAdministration -ErrorAction Stop
    foreach ($site in Get-Website) {
        $binds = (Get-WebBinding -Name $site.Name).bindingInformation
        if ($binds -match ':8888:') {
            Write-Host ("    stop site: " + $site.Name)
            if ($site.State -eq "Started") { Stop-Website -Name $site.Name }
        }
    }
}
catch {
    Write-Host "    cannot stop IIS by site, try net stop W3SVC"
    net stop W3SVC 2>$null | Out-Null
}

if (-not (Test-Port 3306)) {
    Install-LocalMysql
}
Ensure-PaikebangDb

$venvPy = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Host "==> Create venv"
    & $pyExe -m venv .venv
}
Write-Host "==> pip install"
& $venvPy -m pip install -r requirements.txt

Copy-Item (Join-Path $PSScriptRoot ".env.cloud.example") (Join-Path $PSScriptRoot ".env") -Force
Write-Host "==> wrote .env (MySQL 127.0.0.1:3306, public port 8888)"

Get-Process uvicorn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$uvicorn = Join-Path $PSScriptRoot ".venv\Scripts\uvicorn.exe"
Write-Host "==> start uvicorn :8888"
Start-Process -FilePath $uvicorn `
    -ArgumentList "app.main:app --host 0.0.0.0 --port 8888" `
    -WorkingDirectory $PSScriptRoot `
    -RedirectStandardOutput (Join-Path $PSScriptRoot "uvicorn.out.log") `
    -RedirectStandardError (Join-Path $PSScriptRoot "uvicorn.err.log") `
    -WindowStyle Hidden

Start-Sleep -Seconds 5
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:8888/health" -TimeoutSec 20
    Write-Host ("health: " + ($health | ConvertTo-Json -Compress))
}
catch {
    Write-Host "health check failed, see uvicorn.err.log"
    if (Test-Path (Join-Path $PSScriptRoot "uvicorn.err.log")) {
        Get-Content (Join-Path $PSScriptRoot "uvicorn.err.log") -Tail 80
    }
    throw
}

Write-Host "Done. Open http://219.152.92.39:8888/login  admin / 123456"
