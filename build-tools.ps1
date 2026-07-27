# Build Management Tools - Ban Hoa Qua Online
# Su dung: powershell -ExecutionPolicy Bypass -File build-tools.ps1 [option]

param(
    [string]$Action = "help"
)
$LogFile = "build_tools.log"

function Log-Message {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
    Write-Host $logEntry
}


# ==================== CONFIGURATION LOADING & AUTO-DETECTION ====================

function Get-PropertyFromFile {
    param(
        [string]$filePath,
        [string]$propertyName
    )
    if (Test-Path $filePath) {
        $lines = Get-Content $filePath -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith("#")) {
                $parts = $trimmed.Split('=', 2)
                if ($parts.Length -eq 2) {
                    $key = $parts[0].Trim()
                    if ($key -eq $propertyName) {
                        $val = $parts[1].Trim()
                        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                            $val = $val.Substring(1, $val.Length - 2)
                        }
                        return $val.Replace("\\", "/").Replace("\", "/")
                    }
                }
            }
        }
    }
    return $null
}

function Verify-JavaHome {
    param([string]$path)
    if ($path) {
        $cleanPath = $path.Replace("\\", "/").Replace("\", "/").Trim()
        if (Test-Path "$cleanPath\bin\javac.exe") {
            return (Get-Item $cleanPath).FullName
        }
    }
    return $null
}

function Verify-CatalinaHome {
    param([string]$path)
    if ($path) {
        $cleanPath = $path.Replace("\\", "/").Replace("\", "/").Trim()
        if ((Test-Path "$cleanPath\bin\startup.bat") -and (Test-Path "$cleanPath\lib\catalina.jar")) {
            return (Get-Item $cleanPath).FullName
        }
    }
    return $null
}

function Find-JavaHome {
    # 1. Try env variable
    $resolvedHome = Verify-JavaHome $env:JAVA_HOME
    if ($resolvedHome) { return $resolvedHome }

    # 2. Try NetBeans properties
    if (Test-Path "nbproject/private/private.properties") {
        $userProps = Get-PropertyFromFile "nbproject/private/private.properties" "user.properties.file"
        if ($userProps -and (Test-Path $userProps)) {
            $lines = Get-Content $userProps -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match '^platforms\.[^.]+\.home\s*=\s*(.+)') {
                    $p = $Matches[1].Trim()
                    $resolvedHome = Verify-JavaHome $p
                    if ($resolvedHome) { return $resolvedHome }
                }
            }
        }
    }

    # 3. Check Registry (Windows)
    $regPaths = @(
        "HKLM:\SOFTWARE\JavaSoft\JDK",
        "HKLM:\SOFTWARE\JavaSoft\Java Development Kit",
        "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment"
    )
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $jh = Get-ItemProperty -Path $regPath -Name "JavaHome" -ErrorAction SilentlyContinue
            if ($jh) {
                $resolvedHome = Verify-JavaHome $jh.JavaHome
                if ($resolvedHome) { return $resolvedHome }
            }
            $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
            foreach ($sub in $subKeys) {
                $jhSub = Get-ItemProperty -Path $sub.PSPath -Name "JavaHome" -ErrorAction SilentlyContinue
                if ($jhSub) {
                    $resolvedHome = Verify-JavaHome $jhSub.JavaHome
                    if ($resolvedHome) { return $resolvedHome }
                }
            }
        }
    }

    # 4. Check typical locations
    $commonDirs = @(
        "C:\Program Files\Java",
        "C:\Program Files (x86)\Java"
    )
    foreach ($dir in $commonDirs) {
        if (Test-Path $dir) {
            $jdks = Get-ChildItem -Path $dir -Directory -Filter "jdk-*" -ErrorAction SilentlyContinue
            $jdks = $jdks | Sort-Object Name -Descending
            foreach ($jdk in $jdks) {
                $resolvedHome = Verify-JavaHome $jdk.FullName
                if ($resolvedHome) { return $resolvedHome }
            }
        }
    }

    # 5. Check PATH command 'where java'
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $javaExe = $javaCmd.Source
        $parent = Split-Path (Split-Path $javaExe -Parent) -Parent
        $resolvedHome = Verify-JavaHome $parent
        if ($resolvedHome) { return $resolvedHome }
    }

    return $null
}

function Find-CatalinaHome {
    # 1. Try env variable
    $resolvedHome = Verify-CatalinaHome $env:CATALINA_HOME
    if ($resolvedHome) { return $resolvedHome }

    # 2. Try NetBeans configuration
    if (Test-Path "nbproject/private/private.properties") {
        $nbHome = Get-PropertyFromFile "nbproject/private/private.properties" "j2ee.server.home"
        $resolvedHome = Verify-CatalinaHome $nbHome
        if ($resolvedHome) { return $resolvedHome }

        $antProps = Get-PropertyFromFile "nbproject/private/private.properties" "deploy.ant.properties.file"
        if ($antProps -and (Test-Path $antProps)) {
            $tcHome = Get-PropertyFromFile $antProps "tomcat.home"
            $resolvedHome = Verify-CatalinaHome $tcHome
            if ($resolvedHome) { return $resolvedHome }
        }
    }

    # 3. Check typical directories
    $userProfile = $env:USERPROFILE
    $commonDirs = @(
        "C:\Program Files\Apache Software Foundation",
        "C:\apache-tomcat-*",
        "C:\",
        "$userProfile\Downloads",
        "$userProfile"
    )
    foreach ($dir in $commonDirs) {
        if ($dir.Contains("*")) {
            $matches = Get-Item $dir -ErrorAction SilentlyContinue
            foreach ($m in $matches) {
                if ($m.PSIsContainer) {
                    $resolvedHome = Verify-CatalinaHome $m.FullName
                    if ($resolvedHome) { return $resolvedHome }
                }
            }
        } elseif (Test-Path $dir) {
            $tcDirs = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*tomcat*" -or $_.Name -like "*apache-tomcat*" }
            $tcDirs = $tcDirs | Sort-Object Name -Descending
            foreach ($tcd in $tcDirs) {
                $resolvedHome = Verify-CatalinaHome $tcd.FullName
                if ($resolvedHome) { return $resolvedHome }
                
                $subDirs = Get-ChildItem -Path $tcd.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*tomcat*" -or $_.Name -like "*apache-tomcat*" }
                foreach ($sub in $subDirs) {
                    $resolvedHome = Verify-CatalinaHome $sub.FullName
                    if ($resolvedHome) { return $resolvedHome }
                }
            }
        }
    }

    return $null
}

function Find-CatalinaBase {
    param([string]$catalinaHome)
    if ($env:CATALINA_BASE -and (Test-Path "$env:CATALINA_BASE\conf")) {
        return (Get-Item $env:CATALINA_BASE).FullName
    }

    $userProfile = $env:USERPROFILE
    $bases = @(
        "$userProfile\.tomcat",
        "$userProfile\AppData\Roaming\NetBeans\*\apache-tomcat-*"
    )
    foreach ($b in $bases) {
        if ($b.Contains("*")) {
            $matches = Get-Item $b -ErrorAction SilentlyContinue
            foreach ($m in $matches) {
                if ($m.PSIsContainer -and (Test-Path "$($m.FullName)\conf")) {
                    return $m.FullName
                }
            }
        } elseif (Test-Path "$b\conf") {
            return (Get-Item $b).FullName
        }
    }

    return $catalinaHome
}

# 1. Initialize empty vars
$JAVA_HOME = $null
$CATALINA_HOME = $null
$CATALINA_BASE = $null

# 2. Check if .env and tomcat_config.ini exist or create from templates
if (-not (Test-Path "tomcat_config.ini") -and (Test-Path "tomcat_config.ini.template")) {
    Copy-Item "tomcat_config.ini.template" "tomcat_config.ini"
    Log-Message "Created tomcat_config.ini from template." "INFO"
}
if (-not (Test-Path ".env") -and (Test-Path ".env.template")) {
    Copy-Item ".env.template" ".env"
    Log-Message "Created .env from template." "INFO"
}

# 3. Load env variables into process
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split('=', 2)
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }
                [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
    }
}

# 4. Try loading from tomcat_config.ini
if (Test-Path "tomcat_config.ini") {
    Get-Content "tomcat_config.ini" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split('=', 2)
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                if ($key -eq "JAVA_HOME") { $JAVA_HOME = Verify-JavaHome $val }
                elseif ($key -eq "CATALINA_HOME") { $CATALINA_HOME = Verify-CatalinaHome $val }
                elseif ($key -eq "CATALINA_BASE" -and $val -and $val -ne "auto-detect") { 
                    if (Test-Path "$val\conf") { $CATALINA_BASE = (Get-Item $val).FullName }
                }
            }
        }
    }
}

# 5. Fallback auto-detection if still null or invalid
if (-not $JAVA_HOME) {
    $JAVA_HOME = Find-JavaHome
}
if (-not $CATALINA_HOME) {
    $CATALINA_HOME = Find-CatalinaHome
}

# 6. Interactive prompt if still not found and save configuration
$saveConfig = $false
if (-not $JAVA_HOME) {
    Write-Host "`n====================================================================" -ForegroundColor Red
    Write-Host " [!] KHONG TIM THAY THU MUC JDK PHU HOP (Can bin\javac.exe de compile)" -ForegroundColor Red
    Write-Host "====================================================================" -ForegroundColor Red
    $javaInput = Read-Host "Nhap duong dan den JDK cua ban (vi du: C:\Program Files\Java\jdk-17)"
    $JAVA_HOME = Verify-JavaHome $javaInput
    while (-not $JAVA_HOME -and $javaInput) {
        Write-Host "[ERROR] Duong dan JDK khong hop le (khong tim thay bin\javac.exe)!" -ForegroundColor Red
        $javaInput = Read-Host "Nhap lai hoac nhan Ctrl+C de thoat"
        $JAVA_HOME = Verify-JavaHome $javaInput
    }
    if ($JAVA_HOME) { $saveConfig = $true }
}

if (-not $CATALINA_HOME) {
    Write-Host "`n====================================================================" -ForegroundColor Red
    Write-Host " [!] KHONG TIM THAY THU MUC TOMCAT HOME PHU HOP" -ForegroundColor Red
    Write-Host "====================================================================" -ForegroundColor Red
    $tomcatInput = Read-Host "Nhap duong dan den Tomcat cua ban (vi du: C:\apache-tomcat-10.1.55)"
    $CATALINA_HOME = Verify-CatalinaHome $tomcatInput
    while (-not $CATALINA_HOME -and $tomcatInput) {
        Write-Host "[ERROR] Duong dan Tomcat khong hop le (khong tim thay bin\startup.bat hoac lib\catalina.jar)!" -ForegroundColor Red
        $tomcatInput = Read-Host "Nhap lai hoac nhan Ctrl+C de thoat"
        $CATALINA_HOME = Verify-CatalinaHome $tomcatInput
    }
    if ($CATALINA_HOME) { $saveConfig = $true }
}

# Resolve base
if (-not $CATALINA_BASE -and $CATALINA_HOME) {
    $CATALINA_BASE = Find-CatalinaBase $CATALINA_HOME
}

# Save configuration back to ini if we prompted or if we detected new working paths
if ($saveConfig -and $JAVA_HOME -and $CATALINA_HOME) {
    $configContent = "# Tomcat Configuration - Generated $(Get-Date)`r`n" +
                     "JAVA_HOME=$JAVA_HOME`r`n" +
                     "CATALINA_HOME=$CATALINA_HOME`r`n" +
                     "CATALINA_BASE=$CATALINA_BASE"
    $configContent | Out-File "tomcat_config.ini" -Encoding utf8
    Log-Message "Saved working configuration to tomcat_config.ini" "INFO"
}

# Set JRE_HOME same as JAVA_HOME
$JRE_HOME = $JAVA_HOME

# Set environment variables so Tomcat startup.bat and commands see them
$env:JAVA_HOME = $JAVA_HOME
$env:JRE_HOME = $JRE_HOME
if ($CATALINA_HOME) { $env:CATALINA_HOME = $CATALINA_HOME }
if ($CATALINA_BASE) { $env:CATALINA_BASE = $CATALINA_BASE }
$env:JAVA_OPTS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"
$env:CATALINA_OPTS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"
$env:PATH = "$JAVA_HOME\bin;" + $env:PATH

function Assert-RuntimeConfiguration {
    $errors = @()

    if (-not $JAVA_HOME -or -not (Test-Path "$JAVA_HOME\bin\javac.exe")) {
        $errors += "JAVA_HOME khong hop le hoac khong co bin\javac.exe"
    }
    if (-not $CATALINA_HOME -or -not (Test-Path "$CATALINA_HOME\bin\startup.bat") -or -not (Test-Path "$CATALINA_HOME\lib\catalina.jar")) {
        $errors += "CATALINA_HOME khong hop le hoac khong co bin\startup.bat / lib\catalina.jar"
    }

    if ($errors.Count -gt 0) {
        Write-Host "`n===== RUNTIME CONFIGURATION ERROR =====" -ForegroundColor Red
        foreach ($errorMsg in $errors) {
            Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
        }
        Write-Host "[INFO] Kiem tra file tomcat_config.ini va bien moi truong hien tai." -ForegroundColor Yellow
        return $false
    }

    return $true
}



function Show-Help {
    Write-Host @"
====================================================================
BUILD AND DEPLOY MANAGEMENT TOOLS
====================================================================

Cach su dung: powershell -ExecutionPolicy Bypass -File build-tools.ps1 [option]

Cac tuy chon:
  help           - Hien thi tro giup nay
  status         - Kiem tra trang thai Tomcat va cac port
  clean-all      - Xoa toan bo cache va build output
  clean-logs     - Xoa toan bo log files
  kill-tomcat    - Kill Tomcat process va giai phong port
  logs           - Hien thi recent logs
  reset          - Dat lai toan bo va xoa lock file
  install-config - Cau hinh lai Tomcat paths
  open           - Mo ung dung trong browser (http://localhost:8080/Ban_Hoa_Qua_Online/)
  deploy         - Chay toan bo quy trinh (Clean, Build, Deploy, Run & Watch)
  reload         - Recompile nhanh va Hot-Reload Tomcat (giu nguyen Session)
  test           - Chay kiem thu unit tests JUnit cho he thong
  setup-db       - Khoi tao lai database tu .env va Setup_OnlineFruitShopping.sql


Docker options:
  docker-build   - Build Docker image tu Dockerfile
  docker-up      - Khoi chay ung dung bang Docker Compose
  docker-down    - Dung va xoa container Docker
  docker-logs    - Xem log thoi gian thuc cua container Docker
  docker-reset   - Reset sach se Docker (xoa container, volume, va image)

Vi du:
  powershell -ExecutionPolicy Bypass -File build-tools.ps1 status
  powershell -ExecutionPolicy Bypass -File build-tools.ps1 docker-up

====================================================================
"@
}

function Show-Status {
    Write-Host "`n===== TOMCAT and PORT STATUS =====" -ForegroundColor Cyan

    Write-Host "`n===== RUNTIME DETECTION =====" -ForegroundColor Cyan
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        Write-Host "[INFO] java on PATH: $($javaCmd.Source)" -ForegroundColor Gray
    }
    Write-Host "[INFO] JAVA_HOME: $JAVA_HOME" -ForegroundColor Gray
    Write-Host "[INFO] JRE_HOME: $JRE_HOME" -ForegroundColor Gray
    Write-Host "[INFO] CATALINA_HOME: $CATALINA_HOME" -ForegroundColor Gray
    Write-Host "[INFO] CATALINA_BASE: $CATALINA_BASE" -ForegroundColor Gray
    
    # Check ports
    $ports = @(8080, 8005, 5005)  # 5005 for debug port
    foreach ($port in $ports) {
        $connection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($connection) {
            Write-Host "[OK] Port $($port): IN USE (PID: $($connection.OwningProcess))" -ForegroundColor Green
        } else {
            Write-Host "[FREE] Port $($port): FREE" -ForegroundColor Yellow
        }
    }
    
    # Check Tomcat directories
    Write-Host "`n===== CACHE and BUILD DIRECTORIES =====" -ForegroundColor Cyan
    
    # Safely get CATALINA_BASE
    $basePath = ""
    if ($env:CATALINA_BASE) { $basePath = $env:CATALINA_BASE }
    
    $dirs = @(
        "build/web",
        "build/generated-sources"
    )
    if ($basePath) {
        $dirs += "$basePath/work"
        $dirs += "$basePath/temp"
        $dirs += "$basePath/logs"
    }
    
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            $files = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue
            $size = 0
            if ($files) {
                $size = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
            }
            if (-not $size) { $size = 0 }
            Write-Host "[OK] $dir : $([math]::Round($size, 2)) MB" -ForegroundColor Green
        } else {
            Write-Host "[NOT FOUND] $dir : NOT EXISTS" -ForegroundColor Yellow
        }
    }
    
    # Check log files
    Write-Host "`n===== LOG FILES =====" -ForegroundColor Cyan
    $logFiles = @(
        "build_deploy.log",
        "build_errors.log",
        "build_debug.log",
        "build.lock"
    )
    
    foreach ($log in $logFiles) {
        if (Test-Path $log) {
            $lines = (Get-Content $log | Measure-Object -Line).Lines
            Write-Host "[OK] $log : $lines lines" -ForegroundColor Green
        }
    }
}

function Clean-All {
    Write-Host "`n===== CLEANING ALL CACHE and BUILD OUTPUT =====" -ForegroundColor Yellow
    
    $basePath = ""
    if ($env:CATALINA_BASE) { $basePath = $env:CATALINA_BASE }
    
    $dirs = @(
        "build/web/WEB-INF/classes"
    )
    if ($basePath) {
        $dirs += "$basePath/work"
        $dirs += "$basePath/temp"
        $dirs += "$basePath/webapps/Ban_Hoa_Qua_Online"
    }
    
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Write-Host "Removing: $dir" -ForegroundColor Yellow
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host "Cleanup completed!" -ForegroundColor Green
    Log-Message "Clean-all executed"
}

function Clean-Logs {
    Write-Host "`n===== CLEANING LOG FILES =====" -ForegroundColor Yellow
    
    $logFiles = @(
        "build_deploy.log",
        "build_errors.log",
        "build_debug.log",
        "compile_watch.log",
        "compile_output.log"
    )
    
    foreach ($log in $logFiles) {
        if (Test-Path $log) {
            Remove-Item $log -Force
            Write-Host "Removed: $log" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Log cleanup completed!" -ForegroundColor Green
    Log-Message "Clean-logs executed"
}

function Kill-Tomcat {
    Write-Host "`n===== KILLING TOMCAT PROCESS =====" -ForegroundColor Yellow
    
    $ports = @(8080, 8005)
    foreach ($port in $ports) {
        $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                Write-Host "Killing process $($conn.OwningProcess) on port $port" -ForegroundColor Yellow
                Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Write-Host "Tomcat process killed!" -ForegroundColor Green
    Log-Message "Kill-tomcat executed"
}

function Show-Logs {
    Write-Host "`n===== RECENT LOGS =====" -ForegroundColor Cyan
    
    if (Test-Path "build_deploy.log") {
        Write-Host "`n--- MAIN LOG (last 30 lines) ---" -ForegroundColor Green
        Get-Content "build_deploy.log" -Tail 30 | Write-Host
    }
    
    if (Test-Path "build_errors.log") {
        Write-Host "`n--- ERROR LOG ---" -ForegroundColor Red
        Get-Content "build_errors.log" | Write-Host
    }
}

function Reset-All {
    Write-Host "`n===== RESETTING ALL =====" -ForegroundColor Red
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  1. Kill Tomcat" -ForegroundColor Yellow
    Write-Host "  2. Clean all cache" -ForegroundColor Yellow
    Write-Host "  3. Remove build.lock" -ForegroundColor Yellow
    Write-Host "  4. Clean log files" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Are you sure? (yes/no)"
    if ($confirm -eq "yes") {
        Kill-Tomcat
        Start-Sleep -Seconds 2
        Clean-All
        Clean-Logs
        if (Test-Path "build.lock") {
            Remove-Item "build.lock" -Force
            Write-Host "Removed build.lock" -ForegroundColor Green
        }
        Write-Host "`nReset completed! Run clean_build_run.bat de rebuild." -ForegroundColor Green
        Log-Message "Reset-all executed"
    } else {
        Write-Host "Reset cancelled" -ForegroundColor Yellow
    }
}

function Install-Config {
    Write-Host "`n===== TOMCAT CONFIGURATION =====" -ForegroundColor Cyan
    Write-Host "Enter Tomcat paths (or press Enter to keep current/detected values):" -ForegroundColor Yellow
    Write-Host ""
    
    $defaultJava = if ($JAVA_HOME) { $JAVA_HOME } else { "C:\Program Files\Java\jdk-17" }
    $defaultCatalina = if ($CATALINA_HOME) { $CATALINA_HOME } else { "C:\apache-tomcat-10.1.55" }
    $defaultBase = if ($CATALINA_BASE) { $CATALINA_BASE } else { "auto-detect" }

    $java = Read-Host "Java Home [$defaultJava]"
    $catalina = Read-Host "Tomcat Home [$defaultCatalina]"
    $base = Read-Host "Tomcat Instance [$defaultBase]"
    
    $finalJava = if ($java) { Verify-JavaHome $java } else { $defaultJava }
    if ($java -and -not $finalJava) {
        Write-Host "[WARN] Duong dan JDK vua nhap khong hop le (khong tim thay bin\javac.exe). Giu nguyen gia tri mac dinh." -ForegroundColor Yellow
        $finalJava = $defaultJava
    }
    
    $finalCatalina = if ($catalina) { Verify-CatalinaHome $catalina } else { $defaultCatalina }
    if ($catalina -and -not $finalCatalina) {
        Write-Host "[WARN] Duong dan Tomcat vua nhap khong hop le (khong tim thay bin\startup.bat hoac lib\catalina.jar). Giu nguyen gia tri mac dinh." -ForegroundColor Yellow
        $finalCatalina = $defaultCatalina
    }
    
    $finalBase = if ($base) { $base } else { $defaultBase }
    
    $config = "# Tomcat Configuration - Generated $(Get-Date)`r`n" +
              "JAVA_HOME=$finalJava`r`n" +
              "CATALINA_HOME=$finalCatalina`r`n" +
              "CATALINA_BASE=$finalBase"
    
    $config | Out-File "tomcat_config.ini" -Encoding utf8
    Write-Host "Configuration saved to tomcat_config.ini" -ForegroundColor Green
    
    # Reload local variables
    $global:JAVA_HOME = $finalJava
    $global:JRE_HOME = $finalJava
    $global:CATALINA_HOME = $finalCatalina
    $global:CATALINA_BASE = if ($finalBase -eq "auto-detect") { Find-CatalinaBase $finalCatalina } else { $finalBase }
    
    $env:JAVA_HOME = $global:JAVA_HOME
    $env:JRE_HOME = $global:JRE_HOME
    $env:CATALINA_HOME = $global:CATALINA_HOME
    $env:CATALINA_BASE = $global:CATALINA_BASE
    $env:JAVA_OPTS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"
    $env:CATALINA_OPTS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"
    
    Log-Message "Install-config executed, updated configuration saved."
}

function Open-App {
    $appUrl = "http://localhost:8080/Ban_Hoa_Qua_Online/"
    Write-Host "`nOpening application..." -ForegroundColor Cyan
    Write-Host "URL: $appUrl" -ForegroundColor Green
    
    try {
        $response = Invoke-WebRequest -Uri $appUrl -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] Application is running!" -ForegroundColor Green
        }
    } catch {
        Write-Host "[WARN] Application may not be running. Starting browser anyway..." -ForegroundColor Yellow
    }
    
    Start-Process $appUrl
    Write-Host "Browser opened!" -ForegroundColor Green
    Log-Message "Open-app executed"
}

function Compile-Java-Atomic {
    param(
        [string]$webBuildDir,
        [string]$tomcatHome,
        [string]$classpath,
        [string]$compileLogFile  # kept for call-site compat; no longer used (output captured in-memory)
    )
    
    $classesDir = "$webBuildDir/WEB-INF/classes"
    $classesTempDir = "$webBuildDir/WEB-INF/classes_temp"
    
    if (Test-Path $classesTempDir) {
        Remove-Item $classesTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $classesTempDir -Force | Out-Null
    
    $javaFiles = Get-ChildItem -Path "src/java" -Filter "*.java" -Recurse | ForEach-Object { $_.FullName }
    if (-not $javaFiles) {
        Write-Host "[ERROR] No Java files found in src/java!" -ForegroundColor Red
        return $false
    }
    
    # Sử dụng đường dẫn tuyệt đối để tránh lỗi "file not found: sources.txt" do lệch working directory
    $sourcesTxtPath = Join-Path (Get-Location).Path "sources.txt"
    [System.IO.File]::WriteAllLines($sourcesTxtPath, $javaFiles)
    
    # Capture javac output in-memory — no temp file, no file-lock risk
    $javacArgs = "-encoding UTF-8 -g:none -nowarn -target 17 -source 17 -cp `"$classpath`" -d `"$classesTempDir`" @`"$sourcesTxtPath`""
    $compileOutput = cmd.exe /c "javac $javacArgs 2>&1"
    $javacExit = $LASTEXITCODE
    if (Test-Path $sourcesTxtPath) { Remove-Item $sourcesTxtPath -Force -ErrorAction SilentlyContinue }
    
    if ($javacExit -eq 0) {
        if (-not (Test-Path $classesDir)) {
            New-Item -ItemType Directory -Path $classesDir -Force | Out-Null
        }
        
        # Đồng bộ các class file mà không dùng /mir (tránh làm rỗng thư mục gốc khiến Tomcat reload bị sập 404)
        Start-Process -FilePath "robocopy" `
            -ArgumentList "`"$classesTempDir`"", "`"$classesDir`"", "/e", "/w:1", "/r:1", "/ndl", "/nfl" `
            -NoNewWindow -Wait
            
        Remove-Item $classesTempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    } else {
        # Print compiler errors — output was already captured in-memory, nothing to unlock
        if ($compileOutput) {
            Write-Host "=================== COMPILATION ERRORS ===================" -ForegroundColor Red
            Write-Host ($compileOutput -join "`n") -ForegroundColor Red
            Write-Host "=========================================================" -ForegroundColor Red
        }
        Remove-Item $classesTempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Deploy-App {
    Write-Host "`n===== [1/6] STOPPING TOMCAT AND RELEASING PORTS =====" -ForegroundColor Green
    Kill-Tomcat
    
    Write-Host "`n===== [2/6] CLEANING TOMCAT CACHE =====" -ForegroundColor Green
    Clean-All
    
    # Recreate essential Tomcat folders if Base path exists
    $basePath = ""
    if ($env:CATALINA_BASE) { $basePath = $env:CATALINA_BASE }
    if ($basePath) {
        Write-Host "Recreating Tomcat directories under $basePath..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "$basePath/temp" -Force | Out-Null
        New-Item -ItemType Directory -Path "$basePath/work" -Force | Out-Null
        New-Item -ItemType Directory -Path "$basePath/logs" -Force | Out-Null
    }

    # Detect Tomcat home
    $tomcatHome = ""
    if ($env:CATALINA_HOME) { $tomcatHome = $env:CATALINA_HOME }
    if (-not $tomcatHome) {
        Write-Host "[ERROR] CATALINA_HOME is not set and could not be auto-detected!" -ForegroundColor Red
        return
    }

    Write-Host "`n===== [3/6] SYNCING WEB FILES AND COMPILING JAVA =====" -ForegroundColor Green
    $webSrcDir = "web"
    $webBuildDir = "build/web"

    if (!(Test-Path $webBuildDir)) {
        New-Item -ItemType Directory -Path $webBuildDir -Force | Out-Null
    } else {
        Get-ChildItem -Path $webBuildDir -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    if (Test-Path $webSrcDir) {
        Write-Host "Syncing web files..." -ForegroundColor Yellow
        # Robocopy command
        Start-Process -FilePath "robocopy" `
            -ArgumentList "`"$webSrcDir`"", "`"$webBuildDir`"", "/s", "/e", "/xd", "WEB-INF\classes", "/w:1", "/r:1", "/ndl", "/nfl" `
            -Wait -NoNewWindow
    }

    $classpath = "web/WEB-INF/lib/*;$tomcatHome/lib/*"
    $compileLogFile = "compile_output.log"
    if (Test-Path $compileLogFile) { Remove-Item $compileLogFile -Force }

    $compiled = Compile-Java-Atomic -webBuildDir $webBuildDir -tomcatHome $tomcatHome -classpath $classpath
    if (-not $compiled) {
        Write-Host "[ERROR] Compilation failed. See errors above." -ForegroundColor Red
        return
    }
    Write-Host "Compilation completed successfully!" -ForegroundColor Green

    Write-Host "`n===== [4/6] CREATING TOMCAT CONTEXT XML =====" -ForegroundColor Green
    if ($basePath) {
        $contextConfDir = "$basePath/conf/Catalina/localhost"
        if (!(Test-Path $contextConfDir)) {
            New-Item -ItemType Directory -Path $contextConfDir -Force | Out-Null
        }
        $contextXmlPath = "$contextConfDir/Ban_Hoa_Qua_Online.xml"
        $docBaseAbsolute = (Get-Item "build/web").FullName
        $contextContent = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n" +
                          "<Context docBase=`"$($docBaseAbsolute.Replace('\', '/'))`" path=`"/Ban_Hoa_Qua_Online`" reloadable=`"true`" useHttpOnly=`"true`"/>"
        [System.IO.File]::WriteAllText($contextXmlPath, $contextContent)
        Write-Host "Context XML updated at: $contextXmlPath" -ForegroundColor Yellow

        $rootContextXmlPath = "$contextConfDir/ROOT.xml"
        $rootContextContent = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n" +
                              "<Context docBase=`"$($docBaseAbsolute.Replace('\', '/'))`" reloadable=`"true`" useHttpOnly=`"true`"/>"
        [System.IO.File]::WriteAllText($rootContextXmlPath, $rootContextContent)
        Write-Host "Root context XML updated at: $rootContextXmlPath" -ForegroundColor Yellow
    }

    Start-Process -FilePath "$tomcatHome\bin\startup.bat"
    Write-Host "Tomcat startup script executed." -ForegroundColor Yellow

    # Wait for Tomcat to start
    Write-Host "Waiting for port 8080 (max 20 seconds)..." -ForegroundColor Yellow
    $tomcatStarted = $false
    $startTime = Get-Date
    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds(20)) {
        $connection = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
        if ($connection) {
            $tomcatStarted = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if ($tomcatStarted) {
        Write-Host "[OK] Tomcat is up and running on port 8080!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        Open-App
    } else {
        Write-Host "[WARN] Tomcat port 8080 did not open in time. Trying to open app anyway..." -ForegroundColor Yellow
        Open-App
    }

    Write-Host "`n===== [6/6] STARTING WATCH MODE (Press Ctrl+C to stop) =====" -ForegroundColor Green
    
    # Watch loop
    $lastChecksum = ""
    $isBuildInProgress = $false
    
    while ($true) {
        try {
            Start-Sleep -Seconds 2
            if ($isBuildInProgress) { continue }
            
            # Simple watcher: calculate combined last write times
            $files = Get-ChildItem -Path "src/java", "web" -Recurse -File -ErrorAction SilentlyContinue
            if (-not $files) { continue }
            
            $currentChecksum = ($files | ForEach-Object { $_.LastWriteTime.Ticks }) -join ","
            
            if ($lastChecksum -eq "") {
                $lastChecksum = $currentChecksum
                continue
            }
            
            if ($currentChecksum -ne $lastChecksum) {
                $isBuildInProgress = $true
                Write-Host "`n[WATCH] Change detected. Recompiling & Syncing..." -ForegroundColor Yellow
                $lastChecksum = $currentChecksum
                
                try {
                    # Sync web files first
                    if (Test-Path $webSrcDir) {
                        Start-Process -FilePath "robocopy" `
                            -ArgumentList "`"$webSrcDir`"", "`"$webBuildDir`"", "/s", "/e", "/xd", "WEB-INF\classes", "/w:1", "/r:1", "/ndl", "/nfl" `
                            -Wait -NoNewWindow
                    }
                    # Errors are printed inside Compile-Java-Atomic — no log file involved
                    $compiled = Compile-Java-Atomic -webBuildDir $webBuildDir -tomcatHome $tomcatHome -classpath $classpath
                    if ($compiled) {
                        Write-Host "[WATCH] Recompile and atomic sync completed successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "[WATCH] Recompile failed! See errors above." -ForegroundColor Red
                    }
                } catch {
                    Write-Host "[WATCH] Build error: $_" -ForegroundColor Red
                } finally {
                    $isBuildInProgress = $false
                }
            }
        } catch {
            Write-Host "[WATCH] Warning: Exception occurred in file watch loop: $_" -ForegroundColor Yellow
        }
    }
}

function Deploy-Reload {
    Write-Host "`n===== PERFORMING FAST HOT-RELOAD =====" -ForegroundColor Green
    
    $webSrcDir = "web"
    $webBuildDir = "build/web"
    if (Test-Path $webSrcDir) {
        Write-Host "Syncing web files..." -ForegroundColor Yellow
        Start-Process -FilePath "robocopy" `
            -ArgumentList "`"$webSrcDir`"", "`"$webBuildDir`"", "/s", "/e", "/xd", "WEB-INF\classes", "/w:1", "/r:1", "/ndl", "/nfl" `
            -Wait -NoNewWindow
    }
    
    $tomcatHome = ""
    if ($env:CATALINA_HOME) { $tomcatHome = $env:CATALINA_HOME }
    
    $classpath = "web/WEB-INF/lib/*;$tomcatHome/lib/*"
    
    $compiled = Compile-Java-Atomic -webBuildDir $webBuildDir -tomcatHome $tomcatHome -classpath $classpath
    if ($compiled) {
        Write-Host "[OK] Hot-reload compilation and atomic sync completed successfully!" -ForegroundColor Green
        Write-Host "Tomcat will reload the context in ~1-2 seconds. Active sessions preserved." -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Hot-reload compilation failed. See errors above." -ForegroundColor Red
    }
}

# Docker management functions
function Docker-Build {
    Write-Host "`n===== BUILDING DOCKER IMAGE =====" -ForegroundColor Green
    docker compose build
}

function Docker-Up {
    Write-Host "`n===== STARTING DOCKER CONTAINER =====" -ForegroundColor Green
    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.template") {
            Copy-Item ".env.template" ".env"
            Write-Host "Created .env from template." -ForegroundColor Yellow
        }
    }
    docker compose up -d
    Write-Host "[OK] Docker container is starting up!" -ForegroundColor Green
    Write-Host "Go to: http://localhost:8080/Ban_Hoa_Qua_Online/" -ForegroundColor Cyan
}

function Docker-Down {
    Write-Host "`n===== STOPPING DOCKER CONTAINER =====" -ForegroundColor Yellow
    docker compose down
}

function Docker-Logs {
    Write-Host "`n===== SHOWING DOCKER LOGS (Press Ctrl+C to exit logs) =====" -ForegroundColor Cyan
    docker compose logs -f
}

function Docker-Reset {
    Write-Host "`n===== RESETTING DOCKER (Removing Volumes and Images) =====" -ForegroundColor Red
    docker compose down -v --rmi all
}

function Run-Tests {
    Write-Host "`n===== PREPARING AND RUNNING JUNIT TESTS =====" -ForegroundColor Green
    
    $testLibDir = "lib/test"
    if (-not (Test-Path $testLibDir)) {
        New-Item -ItemType Directory -Path $testLibDir -Force | Out-Null
    }
    
    # Download JUnit if not present
    $junitJar = "$testLibDir/junit-4.13.2.jar"
    if (-not (Test-Path $junitJar)) {
        Write-Host "Downloading JUnit 4..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/junit/junit/4.13.2/junit-4.13.2.jar" -OutFile $junitJar -TimeoutSec 15
    }
    
    # Download Hamcrest if not present
    $hamcrestJar = "$testLibDir/hamcrest-core-1.3.jar"
    if (-not (Test-Path $hamcrestJar)) {
        Write-Host "Downloading Hamcrest Core..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar" -OutFile $hamcrestJar -TimeoutSec 15
    }
    
    # Recompile main classes first
    $webBuildDir = "build/web"
    $tomcatHome = $env:CATALINA_HOME
    
    $classpath = "web/WEB-INF/lib/*;$tomcatHome/lib/*"
    
    Write-Host "Compiling main Java classes..." -ForegroundColor Yellow
    $compiledMain = Compile-Java-Atomic -webBuildDir $webBuildDir -tomcatHome $tomcatHome -classpath $classpath
    if (-not $compiledMain) {
        Write-Host "[ERROR] Main Java compilation failed. See errors above." -ForegroundColor Red
        return
    }
    Write-Host "Main Java compilation OK." -ForegroundColor Green
    
    # Compile tests
    $testBuildDir = "build/test/classes"
    if (Test-Path $testBuildDir) {
        Remove-Item $testBuildDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $testBuildDir -Force | Out-Null
    
    $testFiles = Get-ChildItem -Path "test" -Filter "*.java" -Recurse | ForEach-Object { $_.FullName }
    if (-not $testFiles) {
        Write-Host "[ERROR] No test Java files found in test/!" -ForegroundColor Red
        return
    }
    
    $testSourcesTxtPath = Join-Path (Get-Location).Path "test_sources.txt"
    [System.IO.File]::WriteAllLines($testSourcesTxtPath, $testFiles)
    
    $testClasspath = "build/web/WEB-INF/classes;web/WEB-INF/lib/*;lib/test/*;$tomcatHome/lib/*"
    
    Write-Host "Compiling test Java classes..." -ForegroundColor Yellow
    $testJavacArgs = "-encoding UTF-8 -cp `"$testClasspath`" -d `"$testBuildDir`" @`"$testSourcesTxtPath`""
    $testOutput = cmd.exe /c "javac $testJavacArgs 2>&1"
    $testExit = $LASTEXITCODE
    
    if (Test-Path $testSourcesTxtPath) { Remove-Item $testSourcesTxtPath -Force -ErrorAction SilentlyContinue }
    
    if ($testExit -ne 0) {
        Write-Host "[ERROR] Test compilation failed!" -ForegroundColor Red
        if ($testOutput) { Write-Host ($testOutput -join "`n") -ForegroundColor Red }
        return
    }
    Write-Host "Test compilation completed successfully!" -ForegroundColor Green
    
    # Run tests using JUnit Core
    Write-Host "`nRunning JUnit Tests..." -ForegroundColor Cyan
    $runClasspath = "build/test/classes;build/web/WEB-INF/classes;web/WEB-INF/lib/*;lib/test/*;$tomcatHome/lib/*"
    
    # Dynamically find all test classes under test/test
    $testJavaFiles = Get-ChildItem -Path "test/test" -Filter "*.java" -Recurse | ForEach-Object { $_.BaseName }
    $testClasses = $testJavaFiles | ForEach-Object { "test.$_" }
    
    $cmdRun = "java -cp `"$runClasspath`" org.junit.runner.JUnitCore $($testClasses -join ' ')"
    cmd.exe /c $cmdRun
}

function Find-SqlCmd {
    $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if ($sqlcmd) { return $sqlcmd.Source }
    
    $commonPaths = @(
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\120\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\130\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\140\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\150\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SQLCMD.EXE"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Setup-Database {
    Write-Host "`n===== SETTING UP DATABASE =====" -ForegroundColor Green
    
    if (-not (Test-Path ".env")) {
        Write-Host "[ERROR] Khong tim thay file .env de lay cau hinh database!" -ForegroundColor Red
        return
    }

    # Retrieve database properties from env variables
    $dbHost = [System.Environment]::GetEnvironmentVariable("DB_HOST", "Process")
    $dbPort = [System.Environment]::GetEnvironmentVariable("DB_PORT", "Process")
    $dbName = [System.Environment]::GetEnvironmentVariable("DB_NAME", "Process")
    $dbUser = [System.Environment]::GetEnvironmentVariable("DB_USER", "Process")
    $dbPassword = [System.Environment]::GetEnvironmentVariable("DB_PASSWORD", "Process")

    if (-not $dbHost) { $dbHost = "localhost" }
    if (-not $dbPort) { $dbPort = "1433" }
    if (-not $dbName) { $dbName = "OnlineFruitShopping" }
    
    Write-Host "Database Host: $dbHost" -ForegroundColor Cyan
    Write-Host "Database Port: $dbPort" -ForegroundColor Cyan
    Write-Host "Database Name: $dbName" -ForegroundColor Cyan
    Write-Host "Database User: $dbUser" -ForegroundColor Cyan

    $sqlcmdPath = Find-SqlCmd
    if (-not $sqlcmdPath) {
        Write-Host "[ERROR] Khong tim thay cong cu sqlcmd.exe tren he thong!" -ForegroundColor Red
        Write-Host "Vui long cai dat Microsoft Command Line Utilities for SQL Server." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Su dung sqlcmd tai: $sqlcmdPath" -ForegroundColor Gray
    
    $setupFile = "database/Setup_OnlineFruitShopping.sql"
    if (-not (Test-Path $setupFile)) {
        Write-Host "[ERROR] Khong tim thay file setup SQL tai: $setupFile" -ForegroundColor Red
        return
    }

    Write-Host "Dang chay file setup database..." -ForegroundColor Yellow

    $serverArg = "$dbHost,$dbPort"
    $argsList = @("-S", $serverArg)
    if ($dbUser -and $dbPassword) {
        $argsList += @("-U", $dbUser, "-P", $dbPassword)
    } else {
        $argsList += @("-E")
    }
    $argsList += @("-f", "65001", "-i", $setupFile)

    Log-Message "Running database setup command: $sqlcmdPath $($argsList -join ' ')" "INFO"
    
    try {
        & $sqlcmdPath @argsList
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Khoi tao va seed database thanh cong!" -ForegroundColor Green
            Log-Message "Database setup completed successfully." "INFO"
        } else {
            Write-Host "[ERROR] Loi khi chay sqlcmd! Exit Code: $LASTEXITCODE" -ForegroundColor Red
            Log-Message "Database setup failed with exit code $LASTEXITCODE." "ERROR"
        }
    } catch {
        Write-Host "[ERROR] Loi khi thuc thi sqlcmd: $_" -ForegroundColor Red
        Log-Message "Error running sqlcmd: $_" "ERROR"
    }
}

function Setup-Tunnel {
    Write-Host "`n===== SETUP CLOUDFLARE TUNNEL =====" -ForegroundColor Green
    
    $tunnelName = Read-Host "Nhap ten tunnel [mac dinh: metafruit]"
    if (-not $tunnelName) { $tunnelName = "metafruit" }
    
    # 1. Option to delete old tunnel
    $cleanOld = Read-Host "Ban co muon xoa tunnel cu cung ten '$tunnelName' neu da ton tai khong? (Y/N)"
    if ($cleanOld -eq "y" -or $cleanOld -eq "Y") {
        Write-Host "Dang xoa tunnel cu '$tunnelName'..." -ForegroundColor Yellow
        cmd.exe /c "cloudflared tunnel delete -f $tunnelName 2>&1"
    }
    
    # 2. Check login
    $certPath = "$env:USERPROFILE\.cloudflared\cert.pem"
    if (Test-Path $certPath) {
        $relogin = Read-Host "Phat hien chung chi cu tai cert.pem. Ban co muon ghi de de dang nhap tai khoan khac khong? (Y/N)"
        if ($relogin -eq "y" -or $relogin -eq "Y") {
            Write-Host "Dang xao luu cert.pem thanh cert.pem.bak..." -ForegroundColor Yellow
            if (Test-Path "$certPath.bak") { Remove-Item "$certPath.bak" -Force }
            Rename-Item $certPath "cert.pem.bak" -Force
            Write-Host "Dang mo trinh duyet de login Cloudflare..." -ForegroundColor Cyan
            cmd.exe /c "cloudflared tunnel login"
        }
    } else {
        Write-Host "Chua dang nhap Cloudflare. Dang mo trinh duyet..." -ForegroundColor Cyan
        cmd.exe /c "cloudflared tunnel login"
    }
    
    # 3. Create Tunnel
    Write-Host "`nDang tao tunnel moi '$tunnelName'..." -ForegroundColor Yellow
    $createOutput = cmd.exe /c "cloudflared tunnel create $tunnelName 2>&1"
    $createOutput | Write-Host
    
    $uuid = $null
    foreach ($line in $createOutput) {
        if ($line -match "with id ([a-f0-9\-]+)") {
            $uuid = $Matches[1]
            break
        }
    }
    
    if (-not $uuid) {
        # Fallback search inside credentials folder
        $credsDir = "$env:USERPROFILE\.cloudflared"
        if (Test-Path $credsDir) {
            $recentJson = Get-ChildItem $credsDir -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($recentJson) {
                $uuid = $recentJson.BaseName
                Write-Host "Khong parse duoc tu output nhung phat hien JSON credentials moi nhat: $uuid" -ForegroundColor Yellow
            }
        }
    }
    
    if ($uuid) {
        Write-Host "`n[OK] Da lay duoc Tunnel UUID: $uuid" -ForegroundColor Green
        
        # 4. Generate/Update cloudflare/config.yml
        $configDir = "cloudflare"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $jsonCredPath = "$env:USERPROFILE\.cloudflared\$uuid.json"
        $escapedCredPath = $jsonCredPath.Replace("\", "\\")
        
        # 4. Lay Custom Domain truoc de cau hinh vao config.yml
        Write-Host "`n=== CAU HINH TEN MIEN CO DINH (CUSTOM DOMAIN) ===" -ForegroundColor Cyan
        $customDomain = Read-Host "Nhap ten mien co dinh cua ban (vi du: fruitshop.yourdomain.com)"
        
        $jsonCredPath = "$env:USERPROFILE\.cloudflared\$uuid.json"
        $escapedCredPath = $jsonCredPath.Replace("\", "\\")
        
        if ($customDomain) {
            $configContent = @"
# Cloudflare Tunnel Config - MetaFruit (Tu dong cap nhat boi build-tools)
tunnel: $uuid
credentials-file: $escapedCredPath
protocol: http2
edge-ip-version: "4"

ingress:
  # Map ten mien co dinh vao Tomcat local
  - hostname: $customDomain
    service: http://127.0.0.1:8080
    originRequest:
      http2Origin: false
      connectTimeout: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100
  # Mac dinh tra ve 404 cho cac truy cap khac
  - service: http_status:404
"@
        } else {
            $configContent = @"
# Cloudflare Tunnel Config - MetaFruit (Tu dong cap nhat boi build-tools)
tunnel: $uuid
credentials-file: $escapedCredPath
protocol: http2
edge-ip-version: "4"

ingress:
  # Route mac dinh toan bo traffic ve Tomcat local
  - service: http://127.0.0.1:8080
    originRequest:
      http2Origin: false
      connectTimeout: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100
"@
        }
        
        $configContent | Out-File "cloudflare/config.yml" -Encoding utf8
        Write-Host "Da cap nhat file cau hinh tai: cloudflare/config.yml" -ForegroundColor Green
        
        # 5. Route DNS option
        if ($customDomain) {
            Write-Host "`nDang map ten mien $customDomain vao tunnel qua CLI..." -ForegroundColor Yellow
            cmd.exe /c "cloudflared tunnel route dns $tunnelName $customDomain 2>&1" | Write-Host
            Write-Host "[OK] Da tro ten mien $customDomain ve tunnel!" -ForegroundColor Green
        } else {
            Write-Host "`n=== HUONG DAN SETUP TREN CLOUDFLARE DASHBOARD ===" -ForegroundColor Cyan
            Write-Host "De chay duoc, ban can cau hinh DNS de tro ten mien ve tunnel nay." -ForegroundColor Yellow
        }
        
        Write-Host "`nCach 2 (Thu cong tren website):" -ForegroundColor White
        Write-Host "  1. Truy cap trang chu: https://dash.cloudflare.com" -ForegroundColor Gray
        Write-Host "  2. Chon Domain cua ban > DNS > Records > Add Record" -ForegroundColor Gray
        Write-Host "  3. Nhap Type: CNAME, Name: <subdomain> (vi du: fruitshop), Target: $uuid.cfargotunnel.com" -ForegroundColor Gray
        Write-Host "  4. Chon Proxy status: Proxied (Dam bao hinh dam may mau cam bat)." -ForegroundColor Gray
        
        # 6. Run Tunnel option
        $runNow = Read-Host "`nBan co muon khoi chay tunnel '$tunnelName' ngay bay gio khong? (Y/N)"
        if ($runNow -eq "y" -or $runNow -eq "Y") {
            Write-Host "Dang chay tunnel..." -ForegroundColor Green
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "title Cloudflare Tunnel - $tunnelName && cloudflared tunnel --config cloudflare/config.yml run"
        }
    } else {
        Write-Host "[ERROR] Khong the tao hoac xac dinh UUID cua tunnel. Vui long kiem tra lai quyen truy cap." -ForegroundColor Red
    }
}

# Main execution
switch ($Action.ToLower()) {
    "help" { Show-Help }
    "status" { Show-Status }
    "clean-all" { Clean-All }
    "clean-logs" { Clean-Logs }
    "kill-tomcat" { Kill-Tomcat }
    "logs" { Show-Logs }
    "reset" { Reset-All }
    "install-config" { Install-Config }
    "open" { Open-App }
    "deploy" { if (Assert-RuntimeConfiguration) { Deploy-App } }
    "reload" { if (Assert-RuntimeConfiguration) { Deploy-Reload } }
    "test" { Run-Tests }
    "setup-db" { Setup-Database }
    "setup-tunnel" { Setup-Tunnel }
    "docker-build" { Docker-Build }
    "docker-up" { Docker-Up }
    "docker-down" { Docker-Down }
    "docker-logs" { Docker-Logs }
    "docker-reset" { Docker-Reset }
    default {
        Write-Host "Unknown option: $Action" -ForegroundColor Red
        Write-Host "Use 'help' for available options" -ForegroundColor Yellow
        Show-Help
    }
}

Write-Host ""
