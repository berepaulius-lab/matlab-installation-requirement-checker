#requires -Version 5.1

param(
    [switch]$ScanAll,
    [switch]$Quiet
)

$latestMatlabRelease = 'R2024b'
$minPowershell = [version]'5.1'

function Parse-Version {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }

    # Extract a numeric version token like 24.0.1 from arbitrary text
    $token = $Raw
    if ($Raw -match '([0-9]+(?:\.[0-9]+)*)') {
        $token = $Matches[1]
    }

    try {
        return [version]$token
    } catch {
        return $null
    }
}

function Get-WindowsStatus {
    $osCaption = $null
    $osBuild = $null
    $edition = $null
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osCaption = $os.Caption
        $osBuild = $os.BuildNumber
        $edition = $os.OperatingSystemSKU
    } catch {
        $osCaption = (Get-ItemProperty 'HKLM:SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion' -ErrorAction SilentlyContinue).ProductName
        $osBuild = [Environment]::OSVersion.Version.Build
    }

    $arch = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
    $psv = $PSVersionTable.PSVersion
    $psOkay = $psv -ge $minPowershell
    $psNote = if ($psOkay) { "PowerShell $psv" } else { "PowerShell $psv (upgrade to $minPowershell or newer)" }
    $value = "{0} (build {1}), {2} — {3}" -f $osCaption, $osBuild, $arch, $psNote

    return [PSCustomObject]@{
        Label = 'Windows'
        Emoji = if ($psOkay) { '🪟' } else { '⚠️' }
        Value = $value.Trim()
        Color = if ($psOkay) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Yellow }
        NeedsDownload = -not $psOkay
        DownloadUrl = 'https://aka.ms/powershell-release?tag=stable'
        WingetId = 'Microsoft.PowerShell'
    }
}

function Get-InternetStatus {
    $target = 'www.microsoft.com'
    $reachable = $false
    try {
        $reachable = Test-NetConnection -ComputerName $target -InformationLevel Quiet -WarningAction SilentlyContinue
    } catch {
        $reachable = $false
    }

    return [PSCustomObject]@{
        Label = 'Internet'
        Emoji = if ($reachable) { '✅' } else { '⚠️' }
        Value = if ($reachable) { "Online (reachable $target)" } else { "Offline (can't reach $target)" }
        Color = if ($reachable) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
        NeedsDownload = $false
    }
}

function Get-DiskStatus {
    try {
        $drive = Get-PSDrive -Name C -ErrorAction Stop
        $freeGb = [math]::Round($drive.Free / 1GB, 1)
        $totalGb = [math]::Round($drive.Used / 1GB + $drive.Free / 1GB, 1)
        $healthy = $freeGb -ge 10
        return [PSCustomObject]@{
            Label = 'System Disk'
            Emoji = if ($healthy) { '✅' } else { '⚠️' }
            Value = "C: $freeGb GB free of $totalGb GB"
            Color = if ($healthy) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
            NeedsDownload = $false
        }
    } catch {
        return [PSCustomObject]@{
            Label = 'System Disk'
            Emoji = '⚠️'
            Value = 'Unable to read disk info'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $false
        }
    }
}

function Get-MemoryStatus {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $healthy = $totalGb -ge 8
        return [PSCustomObject]@{
            Label = 'Memory'
            Emoji = if ($healthy) { '✅' } else { '⚠️' }
            Value = "$freeGb GB free of $totalGb GB RAM"
            Color = if ($healthy) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
            NeedsDownload = $false
        }
    } catch {
        return [PSCustomObject]@{
            Label = 'Memory'
            Emoji = '⚠️'
            Value = 'Unable to read RAM info'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $false
        }
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host "==============================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor DarkCyan
}

function Write-Status {
    param(
        [string]$Label,
        [string]$Emoji,
        [string]$Value,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $padded = ($Label + ':').PadRight(22)
    Write-Host " $Emoji  $padded $Value" -ForegroundColor $Color
}

function Simplify-Status {
    param([PSCustomObject]$Status)

    return [PSCustomObject]@{
        Label         = $Status.Label
        Emoji         = $Status.Emoji
        Value         = $Status.Value
        Color         = ($Status.Color.ToString())
        NeedsDownload = $Status.NeedsDownload
        DownloadUrl   = $Status.DownloadUrl
    }
}

function Get-MatlabStatus {
    $matlabCmd = Get-Command matlab -ErrorAction SilentlyContinue
    if ($null -eq $matlabCmd) {
        return [PSCustomObject]@{
            Label = 'MATLAB'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $false
        }
    }

    return [PSCustomObject]@{
        Label = 'MATLAB'
        Emoji = '✅'
        Value = "Found (`$($matlabCmd.Source)`), latest known $latestMatlabRelease"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
    }
}

function Get-JavaStatus {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $javaCmd) {
        return [PSCustomObject]@{
            Label = 'Java JDK'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://www.oracle.com/java/technologies/downloads/'
            WingetId = 'Microsoft.OpenJDK.17'
        }
    }

    $versionLine = (java -version 2>&1 | Select-Object -First 1)
    if ($versionLine -match '"([0-9]+(?:\\.[0-9]+)*)"') {
        $version = $Matches[1]
    } else {
        $version = $versionLine
    }

    $emoji = '✅'
    $color = [ConsoleColor]::Green
    $needsDownload = $false
    $parsedVersion = Parse-Version -Raw $version

    if ($null -eq $parsedVersion) {
        $emoji = '⚠️'
        $color = [ConsoleColor]::Yellow
        $needsDownload = $true
    } elseif ($parsedVersion -lt [version]'1.8') {
        $emoji = '⚠️'
        $color = [ConsoleColor]::Yellow
        $needsDownload = $true
    }

    return [PSCustomObject]@{
        Label = 'Java JDK'
        Emoji = $emoji
        Value = "Detected ($version)"
        Color = $color
        NeedsDownload = $needsDownload
        DownloadUrl = 'https://www.oracle.com/java/technologies/downloads/'
        WingetId = 'Microsoft.OpenJDK.17'
    }
}

function Get-DotNetStatus {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $dotnetCmd) {
        return [PSCustomObject]@{
            Label = '.NET Runtime'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://dotnet.microsoft.com/en-us/download/dotnet'
            WingetId = 'Microsoft.DotNet.Runtime.8'
        }
    }

    $version = (dotnet --version 2>&1 | Select-Object -First 1)
    return [PSCustomObject]@{
        Label = '.NET Runtime'
        Emoji = '✅'
        Value = "Detected ($version)"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
        DownloadUrl = 'https://dotnet.microsoft.com/en-us/download/dotnet'
        WingetId = 'Microsoft.DotNet.Runtime.8'
    }
}

function Get-CompilerStatus {
    $found = @()
    foreach ($name in 'cl','gcc','clang') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $found += $name
        }
    }

    if ($found.Count -eq 0) {
        return [PSCustomObject]@{
            Label = 'C/C++ Compiler'
            Emoji = '❌'
            Value = 'None detected (add MSVC, GCC, or Clang)'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://visualstudio.microsoft.com/visual-cpp-build-tools/'
            WingetId = 'Microsoft.VisualStudio.2022.BuildTools'
        }
    }

    return [PSCustomObject]@{
        Label = 'C/C++ Compiler'
        Emoji = '✅'
        Value = "Detected: $($found -join ', ')"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
        DownloadUrl = 'https://visualstudio.microsoft.com/visual-cpp-build-tools/'
        WingetId = 'Microsoft.VisualStudio.2022.BuildTools'
    }
}

function Invoke-AutoInstall {
    param([PSCustomObject]$Status)

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { return $false }
    if (-not $Status.WingetId) { return $false }

    Write-Host "Attempting silent install via winget for $($Status.Label)..." -ForegroundColor Cyan
    try {
        winget install --silent --accept-source-agreements --accept-package-agreements $Status.WingetId
        return $true
    } catch {
        Write-Host "winget install failed. Opening the download page instead." -ForegroundColor Yellow
        return $false
    }
}

function Offer-Download {
    param([PSCustomObject]$Status)

    if (-not $Status.NeedsDownload) { return }
    if (-not $Status.DownloadUrl) { return }

    $autoInstalled = $false
    if (Invoke-AutoInstall -Status $Status) {
        $autoInstalled = $true
        Write-Host "winget finished. Re-run the check to confirm." -ForegroundColor Green
    }

    if ($autoInstalled) { return }

    $response = Read-Host "Open the official $($Status.Label) download page now? (Y/N, default Y)"
    if ([string]::IsNullOrWhiteSpace($response) -or $response.Trim().ToUpper() -eq 'Y') {
        try {
            Start-Process $Status.DownloadUrl | Out-Null
        } catch {
            Write-Host "Couldn't launch browser. Please open: $($Status.DownloadUrl)" -ForegroundColor Yellow
        }
    }
}

function Show-Checks {
    $osStatus = Get-WindowsStatus
    Write-Header 'MATLAB Requirement Checker (no MATLAB needed)'
    Write-Status -Label $osStatus.Label -Emoji $osStatus.Emoji -Value $osStatus.Value -Color $osStatus.Color
    Write-Host "Press A then Enter to scan everything, or choose a specific check." -ForegroundColor White
    Write-Host "Missing/outdated items will offer to open the official download page." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [A] Scan all" -ForegroundColor Green
    Write-Host "  [1] MATLAB" -ForegroundColor Gray
    Write-Host "  [2] Java JDK" -ForegroundColor Gray
    Write-Host "  [3] .NET" -ForegroundColor Gray
    Write-Host "  [4] C/C++ compiler" -ForegroundColor Gray
    Write-Host "  [5] Bonus: Internet" -ForegroundColor DarkCyan
    Write-Host "  [6] Bonus: Disk space" -ForegroundColor DarkCyan
    Write-Host "  [7] Bonus: Memory" -ForegroundColor DarkCyan
    Write-Host "  [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Enter choice (default A)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'A' }

    switch ($choice.ToUpper()) {
        'A' { Run-AllChecks }
        '1' { Show-Result (Get-MatlabStatus) }
        '2' { Show-Result (Get-JavaStatus) }
        '3' { Show-Result (Get-DotNetStatus) }
        '4' { Show-Result (Get-CompilerStatus) }
        '5' { Show-Result (Get-InternetStatus) }
        '6' { Show-Result (Get-DiskStatus) }
        '7' { Show-Result (Get-MemoryStatus) }
        'Q' { return }
        Default {
            Write-Host "Unknown choice. Please try again." -ForegroundColor Yellow
            Show-Checks
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the menu"
    Show-Checks
}

function Show-Result {
    param([PSCustomObject]$Status)
    Write-Host ""
    Write-Status -Label $Status.Label -Emoji $Status.Emoji -Value $Status.Value -Color $Status.Color
    if (-not $ScanAll) {
        Offer-Download -Status $Status
    }
}

function Run-AllChecks {
    Write-Host ""
    Show-Result (Get-WindowsStatus)
    Show-Result (Get-MatlabStatus)
    Show-Result (Get-JavaStatus)
    Show-Result (Get-DotNetStatus)
    Show-Result (Get-CompilerStatus)
    Show-Result (Get-InternetStatus)
    Show-Result (Get-DiskStatus)
    Show-Result (Get-MemoryStatus)
}

function Get-AllStatuses {
    return @(
        Get-WindowsStatus
        Get-MatlabStatus
        Get-JavaStatus
        Get-DotNetStatus
        Get-CompilerStatus
        Get-InternetStatus
        Get-DiskStatus
        Get-MemoryStatus
    )
}

# Skip interactive entry when dot-sourced for reuse by other scripts
if ($MyInvocation.InvocationName -ne '.') {
    if ($ScanAll) {
        Run-AllChecks
        if (-not $Quiet) {
            Write-Host ""
            Write-Host "Done." -ForegroundColor Green
        }
        exit 0
    }

    Show-Checks
}
