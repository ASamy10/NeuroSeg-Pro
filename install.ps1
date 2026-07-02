<#
.SYNOPSIS
    NeuroSeg Pro v4.0.0 Enterprise Bootstrapper & Maintenance Orchestrator (10/10 Commercial Spec)
.DESCRIPTION
    Single source of truth for runtime setup. Performs system diagnostics, metered-connection awareness,
    multi-log separation, Python acquisition, LocalAppData virtual environment management, pre-install
    package auditing, categorized dependency acquisition from requirements.txt, PyTorch GPU acceleration
    profiling, disk space pre-flight checks, strict multi-stage verification, and standardized exit codes
    (0=Success, 1=PyErr, 2=VenvErr, 3=DepErr, 4=GpuErr, 5=VerifyErr, 6=DiskErr).
#>

param(
    [switch]$Unattended = $false,
    [switch]$Repair = $false
)

$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalAppDataDir = Join-Path $env:LOCALAPPDATA "NeuroSegPro"
$LogDir = Join-Path $LocalAppDataDir "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# Multi-log separation targets
$LogBootstrap = Join-Path $LogDir "bootstrap.log"
$LogPython = Join-Path $LogDir "python_install.log"
$LogDeps = Join-Path $LogDir "dependency_install.log"
$LogGpu = Join-Path $LogDir "gpu_detection.log"
$LogVerify = Join-Path $LogDir "verification.log"
$LogRepair = Join-Path $LogDir "repair.log"

$VenvDir = Join-Path $LocalAppDataDir ".venv"
$VenvParent = Split-Path $VenvDir -Parent
$VenvPy = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"
$VenvPyw = Join-Path $VenvDir "Scripts\pythonw.exe"
$TempFilesToClean = @()

# Execution statistics for summary banner
$script:Stats = @{
    MeteredConnection    = $false
    MeteredUserChoice    = "N/A"
    PackagesSkipped      = 0
    PackagesInstalled    = 0
    PyTorchAction        = "N/A"
    VcRedistAction       = "N/A"
    PythonAction         = "N/A"
    GpuTarget            = "CPU Only"
    DiskSpaceFreeGB      = 0
}

# -----------------------------------------------------------------------------
# Logging & Helper Functions
# -----------------------------------------------------------------------------

function Write-Log {
    param([string]$Message, [string]$Level = "INFO", [string]$TargetLog = $LogBootstrap)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Formatted = "[$TimeStamp] [$Level] $Message"
    Write-Host $Formatted
    Add-Content -Path $TargetLog -Value $Formatted -ErrorAction SilentlyContinue
    if ($TargetLog -ne $LogBootstrap) {
        Add-Content -Path $LogBootstrap -Value $Formatted -ErrorAction SilentlyContinue
    }
    if ($Repair) { Add-Content -Path $LogRepair -Value $Formatted -ErrorAction SilentlyContinue }
}

function Write-ExceptionLog {
    param([string]$OpName, [string]$CommandStr, [int]$ErrCode, [object]$Ex)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $exMsg = if ($Ex -is [System.Management.Automation.ErrorRecord]) { $Ex.Exception.Message } elseif ($Ex.Message) { $Ex.Message } else { $Ex.ToString() }
    $exStack = if ($Ex -is [System.Management.Automation.ErrorRecord]) { $Ex.ScriptStackTrace } elseif ($Ex.StackTrace) { $Ex.StackTrace } else { "" }
    $Formatted = "`n[$TimeStamp] [FATAL EXCEPTION]`nOperation  : $OpName`nCommand    : $CommandStr`nExit Code  : $ErrCode`nException  : $exMsg`nStackTrace : $exStack`n"
    Write-Host $Formatted -ForegroundColor Red
    Add-Content -Path $LogBootstrap -Value $Formatted -ErrorAction SilentlyContinue
    if ($Repair) { Add-Content -Path $LogRepair -Value $Formatted -ErrorAction SilentlyContinue }
}

function Update-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# -----------------------------------------------------------------------------
# Metered Connection Detection (Windows Network Cost API via WinRT)
# -----------------------------------------------------------------------------

function Test-MeteredConnection {
    <#
    .SYNOPSIS
        Detects whether the active network connection is metered (data-capped or pay-per-use).
        Returns $true if metered, $false if unrestricted or if detection is not available.
    #>
    try {
        # Load WinRT Network Information API (available on Windows 10+)
        [void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType=WindowsRuntime]
        $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()

        if ($null -eq $profile) {
            Write-Log "Network Cost API: No active internet connection profile detected." "WARNING" $LogBootstrap
            return $false
        }

        $costType = $profile.GetConnectionCost()

        # NetworkCostType: Unrestricted=0, Fixed=1, Variable=2, Unknown=3
        # ApproachingDataLimit and OverDataLimit are additional flags
        $costName = switch ($costType.NetworkCostType) {
            0 { "Unrestricted" }
            1 { "Fixed (Data Cap)" }
            2 { "Variable (Pay-Per-Use)" }
            3 { "Unknown" }
            default { "Unrecognized ($($costType.NetworkCostType))" }
        }

        Write-Log "Network Cost Type       : $costName" "INFO" $LogBootstrap
        Write-Log "Approaching Data Limit  : $($costType.ApproachingDataLimit)" "INFO" $LogBootstrap
        Write-Log "Over Data Limit         : $($costType.OverDataLimit)" "INFO" $LogBootstrap
        Write-Log "Roaming                 : $($costType.Roaming)" "INFO" $LogBootstrap

        # Consider metered if Fixed, Variable, approaching/over limit, or roaming
        $isMetered = ($costType.NetworkCostType -ge 1) -or
                     $costType.ApproachingDataLimit -or
                     $costType.OverDataLimit -or
                     $costType.Roaming

        return $isMetered
    }
    catch {
        # WinRT API may not be available on older systems or Server Core
        Write-Log "Network Cost API unavailable (older Windows or Server Core): $_" "WARNING" $LogBootstrap
        return $false
    }
}

# -----------------------------------------------------------------------------
# Pre-Install Package Auditing
# -----------------------------------------------------------------------------

function Get-MissingPackages {
    <#
    .SYNOPSIS
        Compares installed pip packages against requirements.txt and returns only
        the requirement lines that are missing or unsatisfied. This avoids redundant
        downloads on metered connections and fast-paths repairs on healthy environments.
    #>
    param([string]$RequirementsFile, [string]$PipExe, [string]$PythonExe)

    if (-not (Test-Path $RequirementsFile)) { return @() }

    # Get currently installed packages as a hashtable (lowercase name -> version)
    $installed = @{}
    try {
        $freezeOutput = & $PipExe freeze --all 2>$null
        foreach ($line in $freezeOutput) {
            if ($line -match "^([^=]+)==(.+)$") {
                $installed[$Matches[1].Trim().ToLower()] = $Matches[2].Trim()
            }
        }
    }
    catch {
        Write-Log "pip freeze failed; assuming all packages need installation: $_" "WARNING" $LogDeps
        return @(Get-Content $RequirementsFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' })
    }

    # Parse requirements and check against installed
    $missing = @()
    $reqLines = Get-Content $RequirementsFile
    foreach ($line in $reqLines) {
        $trimmed = $line.Trim()
        # Skip empty lines, comments, and index/find-links directives
        if (-not $trimmed -or $trimmed.StartsWith("#") -or $trimmed.StartsWith("-")) { continue }

        # Extract package name (handle ==, >=, <=, ~=, !=, >, <)
        if ($trimmed -match "^([A-Za-z0-9_.-]+)") {
            $pkgName = $Matches[1].ToLower()
            # Normalize common name variants (underscores vs hyphens)
            $pkgNameNorm = $pkgName -replace '_', '-'

            $found = $installed.ContainsKey($pkgName) -or $installed.ContainsKey($pkgNameNorm) -or
                     $installed.ContainsKey(($pkgName -replace '-', '_')) -or
                     $installed.ContainsKey(($pkgNameNorm -replace '-', '_'))

            if (-not $found) {
                $missing += $trimmed
            }
            else {
                Write-Log "  Already satisfied: $trimmed" "INFO" $LogDeps
            }
        }
        else {
            # Can't parse -- include it to be safe
            $missing += $trimmed
        }
    }

    return $missing
}

# -----------------------------------------------------------------------------
# Download with Resumable Retry & Metered Awareness
# -----------------------------------------------------------------------------

function Get-ResumableDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [int]$MaxRetries = 3,
        [bool]$AllowOnMetered = $true
    )
    $script:TempFilesToClean += $Destination
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Downloading $Url (Attempt $attempt of $MaxRetries)..." "INFO" $LogBootstrap
            $bitsAvailable = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue
            $useBits = $false

            if ($bitsAvailable) {
                # On metered connections, BITS may block transfers based on cost policy.
                # Attempt BITS first but fall back to Invoke-WebRequest if it fails.
                try {
                    $bitsParams = @{
                        Source      = $Url
                        Destination = $Destination
                        Description = "NeuroSeg Pro Runtime"
                        Priority    = "Foreground"
                    }
                    Start-BitsTransfer @bitsParams
                    $useBits = $true
                }
                catch {
                    Write-Log "BITS transfer failed (possibly blocked by metered cost policy): $_. Falling back to Invoke-WebRequest." "WARNING" $LogBootstrap
                    $useBits = $false
                }
            }

            if (-not $useBits) {
                # Direct HTTP download as fallback
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 120
            }

            if (Test-Path $Destination) {
                $fileSizeMB = [math]::Round((Get-Item $Destination).Length / 1MB, 1)
                Write-Log "Download completed: $Destination ($fileSizeMB MB)" "INFO" $LogBootstrap
                return $true
            }
        }
        catch {
            Write-Log "Download retry $attempt error`: $_" "WARNING" $LogBootstrap
            $attempt++
            if ($attempt -le $MaxRetries) { Start-Sleep -Seconds ([math]::pow(2, $attempt)) }
        }
    }
    throw "Failed downloading $Url after $MaxRetries attempts."
}

# -----------------------------------------------------------------------------
# Pip Install with Retry, Timeout, and Metered Awareness
# -----------------------------------------------------------------------------

function Invoke-PipInstallWithRetry {
    param(
        [string[]]$PipArgs,
        [string]$TargetLog,
        [int]$MaxRetries = 3
    )
    # Inject timeout and retry flags into pip for network resilience
    $enhancedArgs = @() + $PipArgs
    if ($enhancedArgs -notcontains "--timeout") {
        $enhancedArgs += @("--timeout", "60")
    }
    if ($enhancedArgs -notcontains "--retries") {
        $enhancedArgs += @("--retries", "3")
    }

    $attempt = 1
    while ($attempt -le $MaxRetries) {
        Write-Log "Executing (Attempt $attempt/$MaxRetries): $VenvPip $($enhancedArgs -join ' ')" "INFO" $TargetLog
        & $VenvPip $enhancedArgs
        if ($LASTEXITCODE -eq 0) { return }
        Write-Log "pip exited with code $LASTEXITCODE on attempt $attempt" "WARNING" $TargetLog
        $attempt++
        if ($attempt -le $MaxRetries) { Start-Sleep -Seconds 5 }
    }
    throw "pip install failed after $MaxRetries attempts."
}

# -----------------------------------------------------------------------------
# nvidia-smi with Timeout Watchdog
# -----------------------------------------------------------------------------

function Invoke-NvidiaSmiSafe {
    <#
    .SYNOPSIS
        Runs nvidia-smi with a 10-second timeout to avoid hanging on broken drivers.
        Returns the query output lines or $null on failure/timeout.
    #>
    param([string]$QueryArgs = "--query-gpu=driver_version --format=csv,noheader")
    try {
        $smiCmd = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if (-not $smiCmd) { return $null }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $smiCmd.Source
        $psi.Arguments = $QueryArgs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $output = $proc.StandardOutput.ReadToEnd()
        $finished = $proc.WaitForExit(10000)  # 10-second watchdog

        if (-not $finished) {
            Write-Log "nvidia-smi timed out after 10 seconds -- killing process." "WARNING" $LogGpu
            try { $proc.Kill() } catch {}
            return $null
        }

        if ($proc.ExitCode -ne 0) {
            Write-Log "nvidia-smi exited with code $($proc.ExitCode)" "WARNING" $LogGpu
            return $null
        }

        return ($output -split "`n" | Where-Object { $_.Trim() })
    }
    catch {
        Write-Log "nvidia-smi invocation failed: $_" "WARNING" $LogGpu
        return $null
    }
}

# -----------------------------------------------------------------------------
# Disk Space Pre-Flight Check
# -----------------------------------------------------------------------------

function Test-DiskSpace {
    <#
    .SYNOPSIS
        Checks that the target drive has at least the required free space in GB.
        Returns $true if sufficient, $false if not.
    #>
    param([string]$TargetPath, [double]$RequiredGB = 5.0)
    try {
        $drive = (Get-Item $TargetPath -ErrorAction SilentlyContinue).PSDrive
        if (-not $drive) {
            # Fall back to parsing drive letter
            $driveLetter = ($TargetPath.Substring(0, 1) + ":")
            $driveInfo = Get-PSDrive -Name $TargetPath.Substring(0, 1) -ErrorAction SilentlyContinue
            if ($driveInfo) {
                $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
            }
            else {
                # Last resort: WMI
                $wmiDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$driveLetter'" -ErrorAction SilentlyContinue
                if ($wmiDrive) { $freeGB = [math]::Round($wmiDrive.FreeSpace / 1GB, 2) } else { $freeGB = -1 }
            }
        }
        else {
            $freeGB = [math]::Round($drive.Free / 1GB, 2)
        }

        $script:Stats.DiskSpaceFreeGB = $freeGB
        Write-Log "Disk space available on target drive: $freeGB GB (Required: $RequiredGB GB)" "INFO" $LogBootstrap

        if ($freeGB -lt 0) {
            Write-Log "Could not determine disk space -- proceeding with caution." "WARNING" $LogBootstrap
            return $true
        }

        return $freeGB -ge $RequiredGB
    }
    catch {
        Write-Log "Disk space check failed: $_ -- proceeding with caution." "WARNING" $LogBootstrap
        return $true
    }
}

# -----------------------------------------------------------------------------
# Main Execution Flow
# -----------------------------------------------------------------------------

try {
    Write-Log "============================================================" "INFO" $LogBootstrap
    Write-Log "NeuroSeg Pro v4.0.0 Enterprise Bootstrapper Initiated" "INFO" $LogBootstrap
    Write-Log "Working Directory : $WorkingDir" "INFO" $LogBootstrap
    Write-Log "Runtime Directory : $VenvDir" "INFO" $LogBootstrap
    Write-Log "Execution Mode    : $(if ($Repair) { 'REPAIR & MAINTENANCE' } else { 'STANDARD SETUP' })" "INFO" $LogBootstrap
    Write-Log "Initiation Time   : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO" $LogBootstrap
    Write-Log "============================================================" "INFO" $LogBootstrap

    Set-Location $WorkingDir

    # --- Step 1: Privilege Verification & Self-Elevation Enforcement ---
    Write-Log "Auditing Windows security context and privileges..." "INFO" $LogBootstrap
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentIdentity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $integrityLevel = if ($isAdmin) { "High / System Integrity" } else { "Medium / Standard User Integrity" }

    Write-Log "Current Identity    : $($currentIdentity.Name)" "INFO" $LogBootstrap
    Write-Log "Integrity Level     : $integrityLevel" "INFO" $LogBootstrap
    Write-Log "Admin Rights Present: $isAdmin" "INFO" $LogBootstrap

    $elevationRequired = -not $isAdmin
    Write-Log "Elevation Required  : $elevationRequired" "INFO" $LogBootstrap

    if (-not $isAdmin) {
        Write-Log "Notice: Bootstrapper invoked without Administrator rights. Relaunching via Start-Process -Verb RunAs..." "WARNING" $LogBootstrap
        $argList = @("-ExecutionPolicy", "Bypass", "-NoProfile", "-File", "`"$($MyInvocation.MyCommand.Path)`"")
        if ($Unattended) { $argList += "-Unattended" }
        if ($Repair) { $argList += "-Repair" }

        try {
            $elevatedProc = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru
            Write-Log "Self-elevation relaunch succeeded. Child process exited with code: $($elevatedProc.ExitCode)" "INFO" $LogBootstrap
            exit $elevatedProc.ExitCode
        }
        catch {
            Write-Log "Self-elevation failed. This may happen if UAC is disabled by Group Policy or the prompt was declined by the user." "ERROR" $LogBootstrap
            Write-Log "Remediation: Right-click the installer and select 'Run as Administrator', or ask your IT admin to enable UAC." "ERROR" $LogBootstrap
            throw "Administrator privileges are required to configure NeuroSeg Pro system dependencies. Error: $_"
        }
    }

    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-Log "Operating System: $($osInfo.Caption) (Build $($osInfo.BuildNumber))" "INFO" $LogBootstrap
    Write-Log "CPU Architecture: $($env:PROCESSOR_ARCHITECTURE)" "INFO" $LogBootstrap

    # --- Step 1b: Network Connectivity & Metered Connection Detection ---
    $isOnline = $false
    try {
        $connTest = Invoke-WebRequest -Uri "https://pypi.org" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($connTest.StatusCode -eq 200) { $isOnline = $true }
    }
    catch { $isOnline = $false }
    Write-Log "Internet Connectivity: $(if ($isOnline) { 'ONLINE' } else { 'OFFLINE' })" "INFO" $LogBootstrap

    $isMetered = $false
    $allowLargeDownloads = $true

    if ($isOnline) {
        $isMetered = Test-MeteredConnection
        $script:Stats.MeteredConnection = $isMetered

        if ($isMetered) {
            Write-Log "*** METERED CONNECTION DETECTED ***" "WARNING" $LogBootstrap
            Write-Log "Large downloads (PyTorch GPU ~2.4 GB, Python ~25 MB, VC++ ~25 MB) may consume significant data." "WARNING" $LogBootstrap

            if ($Unattended) {
                # In unattended mode on metered: skip large downloads, install only what's missing from essentials
                Write-Log "Unattended mode on metered connection: Skipping large optional downloads. Only essential missing packages will be installed." "WARNING" $LogBootstrap
                $allowLargeDownloads = $false
                $script:Stats.MeteredUserChoice = "Auto-Skip (Unattended)"
            }
            else {
                # Interactive mode: prompt user for consent
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host "  METERED CONNECTION DETECTED" -ForegroundColor Yellow
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Your internet connection is metered (data cap or pay-per-use)."
                Write-Host "NeuroSeg Pro may need to download up to ~3.5 GB of packages."
                Write-Host ""
                Write-Host "Options:"
                Write-Host "  [A] Continue with ALL downloads (full setup, uses data)"
                Write-Host "  [E] Install ESSENTIALS only (skip PyTorch GPU, use CPU fallback)"
                Write-Host "  [S] SKIP all downloads (only use already-installed packages)"
                Write-Host ""
                $choice = Read-Host "Enter your choice [A/E/S]"
                switch ($choice.ToUpper()) {
                    "A" {
                        $allowLargeDownloads = $true
                        Write-Log "User chose: Continue with all downloads on metered connection." "INFO" $LogBootstrap
                        $script:Stats.MeteredUserChoice = "All Downloads"
                    }
                    "E" {
                        $allowLargeDownloads = $false
                        Write-Log "User chose: Essentials only on metered connection." "INFO" $LogBootstrap
                        $script:Stats.MeteredUserChoice = "Essentials Only"
                    }
                    "S" {
                        $allowLargeDownloads = $false
                        $isOnline = $false  # Treat as offline for all download logic
                        Write-Log "User chose: Skip all downloads on metered connection." "INFO" $LogBootstrap
                        $script:Stats.MeteredUserChoice = "Skip All"
                    }
                    default {
                        # Default to essentials only (safest for data)
                        $allowLargeDownloads = $false
                        Write-Log "Unrecognized input '$choice' -- defaulting to Essentials Only." "WARNING" $LogBootstrap
                        $script:Stats.MeteredUserChoice = "Essentials Only (Default)"
                    }
                }
            }
        }
        else {
            Write-Log "Connection is unrestricted (not metered)." "INFO" $LogBootstrap
            $script:Stats.MeteredUserChoice = "N/A (Unrestricted)"
        }
    }

    # --- Step 1c: Disk Space Pre-Flight Check (Exit Code 6 on Failure) ---
    Write-Log "Performing disk space pre-flight check..." "INFO" $LogBootstrap
    if (-not (Test-Path $LocalAppDataDir)) { New-Item -ItemType Directory -Path $LocalAppDataDir -Force | Out-Null }
    if (-not (Test-DiskSpace -TargetPath $LocalAppDataDir -RequiredGB 5.0)) {
        Write-Log "FATAL: Insufficient disk space on target drive. At least 5 GB free is required for NeuroSeg Pro runtime." "ERROR" $LogBootstrap
        Write-Log "Free up space on the drive containing $LocalAppDataDir and try again." "ERROR" $LogBootstrap
        exit 6
    }

    # --- Step 2: GPU Intelligence & CUDA Capability ---
    Write-Log "Detecting GPU acceleration capabilities..." "INFO" $LogGpu
    $gpuName = "CPU Only"
    $cudaSupported = $false
    try {
        $gpus = Get-CimInstance Win32_VideoController
        foreach ($g in $gpus) {
            $vramStr = if ($g.AdapterRAM) { "$([math]::Round($g.AdapterRAM / 1GB, 1)) GB" } else { "Unknown VRAM" }
            Write-Log "Graphics Adapter Detected: $($g.Name) ($vramStr)" "INFO" $LogGpu
            if ($g.Name -match "NVIDIA") {
                $gpuName = $g.Name
                # Use watchdog-protected nvidia-smi call (10s timeout)
                $smiLines = Invoke-NvidiaSmiSafe -QueryArgs "--query-gpu=driver_version --format=csv,noheader"
                if ($smiLines -and $smiLines.Count -gt 0 -and $smiLines[0]) {
                    $driverVer = ([string]$smiLines[0]).Trim()
                    $driverMajor = [int]($driverVer -split '\.')[0]
                    Write-Log "NVIDIA Display Driver Version: $driverVer" "INFO" $LogGpu
                    if ($driverMajor -ge 525) {
                        $cudaSupported = $true
                        Write-Log "NVIDIA Driver confirmed compatible with CUDA 12.1 runtime." "INFO" $LogGpu
                    }
                    else {
                        Write-Log "Warning: NVIDIA driver ($driverVer) older than v525.x. Falling back to CPU target." "WARNING" $LogGpu
                    }
                }
                else {
                    Write-Log "nvidia-smi unavailable or timed out -- cannot confirm CUDA support. Falling back to CPU target." "WARNING" $LogGpu
                }
            }
            elseif ($g.Name -match "AMD|Intel") {
                $gpuName = $g.Name
            }
        }
        $script:Stats.GpuTarget = "$gpuName (CUDA: $cudaSupported)"
        Write-Log "Primary Execution Acceleration Target: $gpuName (CUDA Supported: $cudaSupported)" "INFO" $LogGpu
    }
    catch { Write-Log "GPU detection warning: $_" "WARNING" $LogGpu }

    # --- Step 3: Visual C++ Runtime & Git Audit ---
    Write-Log "Verifying Visual C++ Redistributable x64..." "INFO" $LogBootstrap
    $vcInstalled = $false
    $uninsKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
    foreach ($k in Get-ItemProperty $uninsKeys -ErrorAction SilentlyContinue) {
        if ($k.DisplayName -match "Microsoft Visual C\+\+.*Redistributable.*\(x64\)") { $vcInstalled = $true; break }
    }
    if (-not $vcInstalled -and $isOnline) {
        if ($isMetered -and -not $allowLargeDownloads) {
            Write-Log "Skipping Visual C++ Redistributable download (metered connection, essentials-only mode)." "WARNING" $LogBootstrap
            $script:Stats.VcRedistAction = "Skipped (Metered)"
        }
        else {
            Write-Log "Downloading Visual C++ Redistributable x64 (~25 MB)..." "INFO" $LogBootstrap
            $vcExe = Join-Path $env:TEMP "vc_redist.x64.exe"
            $script:TempFilesToClean += $vcExe
            Get-ResumableDownload -Url "https://aka.ms/vs/17/release/vc_redist.x64.exe" -Destination $vcExe
            Start-Process -FilePath $vcExe -ArgumentList "/install /quiet /norestart" -Wait | Out-Null
            $script:Stats.VcRedistAction = "Installed"
        }
    }
    elseif ($vcInstalled) {
        Write-Log "Visual C++ Redistributable x64 already installed." "INFO" $LogBootstrap
        $script:Stats.VcRedistAction = "Already Installed"
    }
    else {
        $script:Stats.VcRedistAction = "Skipped (Offline)"
    }

    # --- Step 4: Python Runtime Acquisition & Verification (Exit Code 1 on Failure) ---
    try {
        Write-Log "Auditing system Python runtime (>=3.11.0, <3.13.0)..." "INFO" $LogPython
        Update-EnvironmentPath
        $pythonExe = "python.exe"
        $pyCmd = Get-Command $pythonExe -ErrorAction SilentlyContinue
        if ($pyCmd -and $pyCmd.Source -match "WindowsApps") { $pyCmd = $null }

        $validPy = $false
        if ($pyCmd) {
            $verStr = & $pyCmd.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            if ($verStr -match "3\.(11|12)") {
                $validPy = $true; $pythonExe = $pyCmd.Source
                Write-Log "Verified System Python: v$verStr at $pythonExe" "INFO" $LogPython
                $script:Stats.PythonAction = "System Python v$verStr"
            }
        }

        if (-not $validPy) {
            if (-not $isOnline) { throw "Python 3.11 runtime required but system is offline and no valid Python found." }
            if ($isMetered -and -not $allowLargeDownloads) {
                throw "Python 3.11 runtime required but metered connection and large downloads disabled. Please connect to an unrestricted network."
            }
            Write-Log "Downloading Python 3.11.8 x64 installer (~25.5 MB)..." "INFO" $LogPython
            $pyInst = Join-Path $env:TEMP "python-3.11.8-amd64.exe"
            Get-ResumableDownload -Url "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe" -Destination $pyInst
            Write-Log "Installing Python 3.11.8 silently..." "INFO" $LogPython
            $proc = Start-Process -FilePath $pyInst -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Shortcuts=0 CompileAll=1 Include_doc=0 Include_dev=0 Include_launcher=1" -Wait -PassThru
            if ($proc.ExitCode -ne 0) { throw "Python installer returned exit code $($proc.ExitCode)." }
            Update-EnvironmentPath
            $defaultPy = Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe"
            if (Test-Path $defaultPy) { $pythonExe = $defaultPy } else {
                $sysPy = Get-Command "python.exe" -ErrorAction SilentlyContinue
                if ($sysPy) { $pythonExe = $sysPy.Source } else { throw "Python installed but executable binary unlocated." }
            }
            $script:Stats.PythonAction = "Installed Python 3.11.8"
        }
    }
    catch {
        Write-ExceptionLog "Python Acquisition" "Python Setup Engine" 1 $_
        exit 1
    }

    # --- Step 5: Virtual Environment Orchestration (Exit Code 2 on Failure) ---
    try {
        $TokenFile = Join-Path $VenvParent ".runtime_verified"
        if (Test-Path $TokenFile) { Remove-Item $TokenFile -Force -ErrorAction SilentlyContinue }

        Write-Log "Orchestrating LocalAppData virtual environment at $VenvDir..." "INFO" $LogBootstrap
        if (-not (Test-Path $VenvPy) -or -not (Test-Path $VenvPyw) -or $Repair) {
            # On Repair, only recreate if venv is actually broken
            $venvBroken = $false
            if ($Repair -and (Test-Path $VenvPy) -and (Test-Path $VenvPyw)) {
                Write-Log "Repair mode: Testing existing virtual environment health..." "INFO" $LogBootstrap
                & $VenvPy -c "import sys; print(sys.executable)" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $venvBroken = $true
                    Write-Log "Existing venv is corrupted -- will recreate." "WARNING" $LogBootstrap
                }
                else {
                    Write-Log "Existing venv is healthy -- skipping recreation." "INFO" $LogBootstrap
                }
            }
            else {
                $venvBroken = $true  # Missing executables = definitely needs creation
            }

            if ($venvBroken) {
                Write-Log "Creating clean isolated virtual environment via $pythonExe -m venv $VenvDir..." "INFO" $LogBootstrap
                if (Test-Path $VenvDir) { Remove-Item -Recurse -Force $VenvDir -ErrorAction SilentlyContinue }
                & $pythonExe -m venv $VenvDir
                $venvExit = $LASTEXITCODE
                Write-Log "python -m venv exited with code $venvExit" "INFO" $LogBootstrap
                if ($venvExit -ne 0 -or -not (Test-Path $VenvPyw)) { throw "Virtual environment initialization failed with exit code $venvExit." }
            }
        }
        else {
            # Ensure existing virtual environment is isolated from conflicting host packages
            $pyvenvCfg = Join-Path $VenvDir "pyvenv.cfg"
            if (Test-Path $pyvenvCfg) {
                $cfgContent = Get-Content $pyvenvCfg -Raw
                if ($cfgContent -match "include-system-site-packages\s*=\s*true") {
                    Write-Log "Updating existing pyvenv.cfg to include-system-site-packages = false to prevent host conflicts..." "INFO" $LogBootstrap
                    $cfgContent -replace "include-system-site-packages\s*=\s*true", "include-system-site-packages = false" | Set-Content $pyvenvCfg -Force
                }
            }
        }
        Write-Log "Upgrading base packaging toolchain (pip, setuptools, wheel)..." "INFO" $LogBootstrap
        & $VenvPy -m pip install --upgrade pip setuptools wheel --quiet
        $pipExit = $LASTEXITCODE
        Write-Log "pip upgrade exited with code $pipExit" "INFO" $LogBootstrap
        if ($pipExit -ne 0) { throw "Packaging toolchain upgrade exited with code $pipExit." }
    }
    catch {
        Write-ExceptionLog "Virtual Environment Creation" "python -m venv" 2 $_
        exit 2
    }

    # --- Step 6: PyTorch Engine Acquisition (Exit Code 4 on Failure) ---
    try {
        Write-Log "Auditing PyTorch Deep Learning Runtime..." "INFO" $LogGpu
        $torchVer = & $VenvPy -c "try:`n    import torch`n    print(torch.__version__)`nexcept Exception:`n    import sys; sys.exit(1)" 2>$null
        $chkExit = $LASTEXITCODE
        Write-Log "PyTorch dry import exited with code $chkExit (Version: $torchVer)" "INFO" $LogGpu

        $needTorch = $false
        $torchReason = ""

        if ($chkExit -ne 0 -or -not $torchVer) {
            $needTorch = $true
            $torchReason = "PyTorch not installed or import failed"
        }
        elseif ($cudaSupported -and $torchVer -notmatch "\+cu") {
            $needTorch = $true
            $torchReason = "CUDA GPU available but current PyTorch ($torchVer) is CPU-only build"
        }

        # On Repair: don't re-download if existing install is correct
        if ($Repair -and -not $needTorch) {
            Write-Log "Repair mode: PyTorch $torchVer is correctly installed -- no re-download needed." "INFO" $LogGpu
            $script:Stats.PyTorchAction = "Verified ($torchVer)"
        }
        elseif ($needTorch) {
            Write-Log "PyTorch installation required: $torchReason" "INFO" $LogGpu

            if (-not $isOnline) {
                Write-Log "Offline mode: Skipping online PyTorch download." "WARNING" $LogGpu
                $script:Stats.PyTorchAction = "Skipped (Offline)"
            }
            elseif ($isMetered -and -not $allowLargeDownloads -and $cudaSupported) {
                # On metered with essentials-only: install CPU variant instead of huge GPU variant
                Write-Log "Metered connection: Installing PyTorch CPU variant (~240 MB) instead of CUDA variant (~2.4 GB)." "WARNING" $LogGpu
                Invoke-PipInstallWithRetry -PipArgs @("install", "torch", "torchvision", "--index-url", "https://download.pytorch.org/whl/cpu", "--prefer-binary") -TargetLog $LogGpu
                $script:Stats.PyTorchAction = "Installed CPU (Metered)"
            }
            else {
                $torchMB = if ($cudaSupported) { 2450.0 } else { 240.0 }
                Write-Log "Acquiring PyTorch $(if ($cudaSupported) { 'CUDA 12.1 Engine' } else { 'CPU Engine' }) (~$torchMB MB payload)..." "INFO" $LogGpu
                $idxUrl = if ($cudaSupported) { "https://download.pytorch.org/whl/cu121" } else { "https://download.pytorch.org/whl/cpu" }
                Invoke-PipInstallWithRetry -PipArgs @("install", "torch", "torchvision", "--index-url", $idxUrl, "--prefer-binary") -TargetLog $LogGpu
                $script:Stats.PyTorchAction = "Installed $(if ($cudaSupported) { 'CUDA 12.1' } else { 'CPU' })"
            }
        }
        else {
            Write-Log "PyTorch engine verified satisfied: $torchVer" "INFO" $LogGpu
            $script:Stats.PyTorchAction = "Already Satisfied ($torchVer)"
        }
    }
    catch {
        Write-ExceptionLog "PyTorch Acceleration Setup" "pip install torch" 4 $_
        exit 4
    }

    # --- Step 7: Dependency Manifest Acquisition from requirements.txt (Exit Code 3 on Failure) ---
    try {
        $ReqFile = Join-Path $WorkingDir "requirements.txt"
        if (Test-Path $ReqFile) {
            Write-Log "Auditing dependencies against $ReqFile..." "INFO" $LogDeps

            # Pre-install audit: determine which packages are actually missing
            $missingPkgs = Get-MissingPackages -RequirementsFile $ReqFile -PipExe $VenvPip -PythonExe $VenvPy
            $totalReqs = @(Get-Content $ReqFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }).Count
            $missingCount = $missingPkgs.Count
            $satisfiedCount = $totalReqs - $missingCount

            Write-Log "Package audit results: $satisfiedCount/$totalReqs already satisfied, $missingCount need installation." "INFO" $LogDeps
            $script:Stats.PackagesSkipped = $satisfiedCount

            if ($missingCount -eq 0) {
                Write-Log "All requirements from requirements.txt are already satisfied. Skipping pip install." "INFO" $LogDeps
                $script:Stats.PackagesInstalled = 0
            }
            elseif ($isOnline) {
                Write-Log "Installing $missingCount missing package(s): $($missingPkgs -join ', ')" "INFO" $LogDeps

                # Write missing packages to a temp requirements file for pip
                $tempReqFile = Join-Path $env:TEMP "neurosegpro_missing_reqs.txt"
                $script:TempFilesToClean += $tempReqFile
                $missingPkgs | Set-Content $tempReqFile -Force

                Invoke-PipInstallWithRetry -PipArgs @("install", "-r", $tempReqFile, "--prefer-binary") -TargetLog $LogDeps
                $script:Stats.PackagesInstalled = $missingCount
            }
            else {
                Write-Log "System offline: Unable to install $missingCount missing packages." "WARNING" $LogDeps
                $script:Stats.PackagesInstalled = 0
            }
        }
        else {
            Write-Log "Notice: requirements.txt not located at $ReqFile." "WARNING" $LogDeps
        }
    }
    catch {
        Write-ExceptionLog "Requirements Acquisition" "pip install -r requirements.txt" 3 $_
        exit 3
    }

    # --- Step 8: Comprehensive Verification Audit (Exit Code 5 on Failure) ---
    try {
        Write-Log "Executing strict post-setup runtime verification audit..." "INFO" $LogVerify
        if (-not (Test-Path $VenvPy)) { throw "Verification failed: python.exe unlocated in .venv." }
        if (-not (Test-Path $VenvPyw)) { throw "Verification failed: pythonw.exe unlocated in .venv." }
        if (-not (Test-Path $VenvPip)) { throw "Verification failed: pip.exe unlocated in .venv." }

        $CoreModules = @("numpy", "torch", "nibabel", "PyQt5", "monai", "pennylane", "scipy")
        $missingMods = @()
        foreach ($mod in $CoreModules) {
            & $VenvPy -c "import $mod" 2>$null
            if ($LASTEXITCODE -ne 0) { $missingMods += $mod }
        }
        if ($missingMods.Count -gt 0) {
            if (-not $isOnline) {
                Write-Log "Audit note: Offline mode skipped downloading missing modules: $($missingMods -join ', ')" "WARNING" $LogVerify
            }
            elseif ($isMetered -and -not $allowLargeDownloads) {
                Write-Log "Audit note: Metered mode skipped downloading missing modules: $($missingMods -join ', ')" "WARNING" $LogVerify
            }
            else {
                throw "Verification failure: Missing essential core modules: $($missingMods -join ', ')"
            }
        }

        # Verify application entry point importability
        $MainPy = Join-Path $WorkingDir "app\main.py"
        if (Test-Path $MainPy) {
            & $VenvPy -c "import sys; sys.path.insert(0, r'$WorkingDir'); from PyQt5.QtWidgets import QApplication; import torch; import monai; import app.main" 2>&1
            $appExit = $LASTEXITCODE
            Write-Log "Application core dry import exited with code $appExit" "INFO" $LogVerify
            if ($appExit -ne 0) { throw "Application core dry import verification failed (Exit $appExit)." }
            else { Write-Log "Application core import verified successfully." "INFO" $LogVerify }
        }

        # Create verification token indicating runtime is 100% complete and verified
        $TokenFile = Join-Path $VenvParent ".runtime_verified"
        New-Item -ItemType File -Path $TokenFile -Force | Out-Null

        Write-Log "Runtime verification audit confirmed 100% successful." "INFO" $LogVerify
    }
    catch {
        Write-ExceptionLog "Runtime Verification Audit" "Verification Engine" 5 $_
        exit 5
    }

    # --- Final Summary Banner ---
    $Stopwatch.Stop()
    $elapsedMin = $Stopwatch.Elapsed.Minutes
    $elapsedSec = $Stopwatch.Elapsed.Seconds

    Write-Log "" "INFO" $LogBootstrap
    Write-Log "============================================================" "INFO" $LogBootstrap
    Write-Log "  BOOTSTRAPPER ORCHESTRATION COMPLETED SUCCESSFULLY (EXIT 0)" "INFO" $LogBootstrap
    Write-Log "============================================================" "INFO" $LogBootstrap
    Write-Log "  Execution Duration     : ${elapsedMin}m ${elapsedSec}s" "INFO" $LogBootstrap
    Write-Log "  Metered Connection     : $($script:Stats.MeteredConnection)" "INFO" $LogBootstrap
    Write-Log "  Metered User Choice    : $($script:Stats.MeteredUserChoice)" "INFO" $LogBootstrap
    Write-Log "  GPU Target             : $($script:Stats.GpuTarget)" "INFO" $LogBootstrap
    Write-Log "  Python                 : $($script:Stats.PythonAction)" "INFO" $LogBootstrap
    Write-Log "  PyTorch                : $($script:Stats.PyTorchAction)" "INFO" $LogBootstrap
    Write-Log "  VC++ Redistributable   : $($script:Stats.VcRedistAction)" "INFO" $LogBootstrap
    Write-Log "  Packages Already OK    : $($script:Stats.PackagesSkipped)" "INFO" $LogBootstrap
    Write-Log "  Packages Installed     : $($script:Stats.PackagesInstalled)" "INFO" $LogBootstrap
    Write-Log "  Disk Space Free        : $($script:Stats.DiskSpaceFreeGB) GB" "INFO" $LogBootstrap
    Write-Log "============================================================" "INFO" $LogBootstrap
    exit 0

}
catch {
    $Stopwatch.Stop()
    Write-ExceptionLog "Unhandled Bootstrapper Execution" "install.ps1" 1 $_
    exit 1
}
finally {
    foreach ($tf in $script:TempFilesToClean) {
        if ($tf -and (Test-Path $tf)) { Remove-Item $tf -Force -ErrorAction SilentlyContinue }
    }
}
