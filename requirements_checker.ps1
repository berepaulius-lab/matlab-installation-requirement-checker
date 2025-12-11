#requires -Version 5.1

param(
    [switch]$ScanAll,
    [switch]$Quiet,
    [string]$LogPath,
    [string]$LogFile,
    [switch]$Dashboard,
    [int]$Port = 5133
)

$latestMatlabRelease = 'R2024b'
$minPowershell = [version]'5.1'
$defaultLogRoot = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Logs\MatlabRequirementChecker' } else { Join-Path $PSScriptRoot 'logs' }
$script:LogDirectory = if ($LogPath) { $LogPath } else { $defaultLogRoot }
$script:LogFile = $LogFile
$script:TranscriptStarted = $false

function Initialize-Log {
    try {
        if (-not $script:LogDirectory) {
            $script:LogDirectory = $defaultLogRoot
        }
        if (-not (Test-Path $script:LogDirectory)) {
            New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
        }

        if (-not $script:LogFile) {
            $existing = Get-ChildItem -Path $script:LogDirectory -Filter 'log-*.txt' -ErrorAction SilentlyContinue
            $numbers = @()
            foreach ($item in $existing) {
                if ($item.BaseName -match 'log-(\d+)') {
                    $numbers += [int]$Matches[1]
                }
            }
            $next = if ($numbers.Count -gt 0) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
            $script:LogFile = Join-Path $script:LogDirectory ("log-{0:D3}.txt" -f $next)
        } else {
            $script:LogDirectory = Split-Path -Path $script:LogFile -Parent
            if (-not (Test-Path $script:LogDirectory)) {
                New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
            }
        }

        "[INFO] $(Get-Date -Format o) :: Session started" | Out-File -FilePath $script:LogFile -Encoding UTF8 -Force
    } catch {
        Write-Warning "Could not initialize log folder at $script:LogDirectory: $($_.Exception.Message)"
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $line = "[$Level] $(Get-Date -Format o) :: $Message"
    if ($script:LogFile) {
        try { $line | Out-File -FilePath $script:LogFile -Encoding UTF8 -Append } catch { }
    }
}

function Start-TranscriptSafe {
    try {
        Start-Transcript -Path $script:LogFile -Append -ErrorAction Stop | Out-Null
        $script:TranscriptStarted = $true
    } catch {
        Write-Warning "Transcript could not start: $($_.Exception.Message)"
        Write-Log -Message "Transcript start failed: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Confirm-Logging {
    if ($Quiet -or $Dashboard) { return $true }
    Write-Host "Logging everything to:`n  $script:LogFile" -ForegroundColor Cyan
    Write-Host "A per-user log folder lives at $script:LogDirectory. Send the newest log-###.txt if something looks off." -ForegroundColor DarkGray
    $response = Read-Host "Start logging now? (Y/n)"
    if ($response -and $response.Trim().ToUpper() -eq 'N') {
        Write-Log -Message "User aborted before checks" -Level 'WARN'
        if ($script:TranscriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
        return $false
    }
    return $true
}

Initialize-Log
Start-TranscriptSafe
Write-Log -Message "Arguments: ScanAll=$ScanAll Quiet=$Quiet LogPath=$LogPath"
Write-Log -Message "Logs will be written to $script:LogFile"
if (-not (Confirm-Logging)) { return }

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

    $obj = [PSCustomObject]@{
        Label = 'Windows'
        Emoji = if ($psOkay) { '🪟' } else { '⚠️' }
        Value = $value.Trim()
        Color = if ($psOkay) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Yellow }
        NeedsDownload = -not $psOkay
        DownloadUrl = 'https://aka.ms/powershell-release?tag=stable'
        WingetId = 'Microsoft.PowerShell'
    }

    Write-Log -Message "Windows status: $($obj.Value)"
    return $obj
}

function Get-InternetStatus {
    $target = 'www.microsoft.com'
    $reachable = $false
    try {
        $reachable = Test-NetConnection -ComputerName $target -InformationLevel Quiet -WarningAction SilentlyContinue
    } catch {
        $reachable = $false
    }

    $obj = [PSCustomObject]@{
        Label = 'Internet'
        Emoji = if ($reachable) { '✅' } else { '⚠️' }
        Value = if ($reachable) { "Online (reachable $target)" } else { "Offline (can't reach $target)" }
        Color = if ($reachable) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
        NeedsDownload = $false
    }

    Write-Log -Message "Internet status: $($obj.Value)"
    return $obj
}

function Get-DiskStatus {
    try {
        $drive = Get-PSDrive -Name C -ErrorAction Stop
        $freeGb = [math]::Round($drive.Free / 1GB, 1)
        $totalGb = [math]::Round($drive.Used / 1GB + $drive.Free / 1GB, 1)
        $healthy = $freeGb -ge 10
        $obj = [PSCustomObject]@{
            Label = 'System Disk'
            Emoji = if ($healthy) { '✅' } else { '⚠️' }
            Value = "C: $freeGb GB free of $totalGb GB"
            Color = if ($healthy) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
            NeedsDownload = $false
        }
        Write-Log -Message "Disk status: $($obj.Value)"
        return $obj
    } catch {
        $obj = [PSCustomObject]@{
            Label = 'System Disk'
            Emoji = '⚠️'
            Value = 'Unable to read disk info'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $false
        }
        Write-Log -Message "Disk status error: $($_.Exception.Message)" -Level 'WARN'
        return $obj
    }
}

function Get-MemoryStatus {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $healthy = $totalGb -ge 8
        $obj = [PSCustomObject]@{
            Label = 'Memory'
            Emoji = if ($healthy) { '✅' } else { '⚠️' }
            Value = "$freeGb GB free of $totalGb GB RAM"
            Color = if ($healthy) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
            NeedsDownload = $false
        }
        Write-Log -Message "Memory status: $($obj.Value)"
        return $obj
    } catch {
        $obj = [PSCustomObject]@{
            Label = 'Memory'
            Emoji = '⚠️'
            Value = 'Unable to read RAM info'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $false
        }
        Write-Log -Message "Memory status error: $($_.Exception.Message)" -Level 'WARN'
        return $obj
    }
}

function Get-WingetStatus {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $obj = [PSCustomObject]@{
            Label = 'winget'
            Emoji = '⚠️'
            Value = 'Winget not detected; enable App Installer in Microsoft Store'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $true
            DownloadUrl = 'https://www.microsoft.com/p/app-installer/9nblggh4nns1'
            WingetId = $null
        }
        Write-Log -Message "Winget missing" -Level 'WARN'
        return $obj
    }

    $obj = [PSCustomObject]@{
        Label = 'winget'
        Emoji = '✅'
        Value = "Found ($($cmd.Source))"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
        DownloadUrl = 'https://www.microsoft.com/p/app-installer/9nblggh4nns1'
        WingetId = $null
    }
    Write-Log -Message "Winget present"
    return $obj
}

function Get-WindowsUpdateStatus {
    try {
        $svc = Get-Service -Name wuauserv -ErrorAction Stop
        $running = $svc.Status -eq 'Running'
        $obj = [PSCustomObject]@{
            Label = 'Windows Update'
            Emoji = if ($running) { '✅' } else { '⚠️' }
            Value = if ($running) { 'Service running' } else { 'Service stopped (start for updates)' }
            Color = if ($running) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
            NeedsDownload = -not $running
            DownloadUrl = 'ms-settings:windowsupdate'
        }
        Write-Log -Message "Windows Update status: $($obj.Value)"
        return $obj
    } catch {
        $obj = [PSCustomObject]@{
            Label = 'Windows Update'
            Emoji = '⚠️'
            Value = 'Unable to read update service'
            Color = [ConsoleColor]::Yellow
            NeedsDownload = $true
            DownloadUrl = 'ms-settings:windowsupdate'
        }
        Write-Log -Message "Windows Update query failed: $($_.Exception.Message)" -Level 'WARN'
        return $obj
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
        WingetId      = $Status.WingetId
    }
}

function Write-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Body,
        [string]$ContentType = 'text/plain; charset=utf-8',
        [int]$StatusCode = 200
    )

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $buffer.Length
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.Close()

    $level = if ($StatusCode -ge 400) { 'WARN' } else { 'INFO' }
    Write-Log -Message "Served $ContentType ($StatusCode)" -Level $level
}

function Send-Json {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 4
    Write-Response -Response $Response -Body $json -ContentType 'application/json'
}

function Get-StatusPayload {
    param([PSCustomObject]$Status)
    return Simplify-Status -Status $Status
}

function Get-AllPayloads {
    return (Get-AllStatuses | ForEach-Object { Get-StatusPayload $_ })
}

function Log-Request {
    param(
        [string]$Path,
        [int]$Status = 200
    )
    Write-Log -Message "HTTP $Status for $Path"
}

function New-Listener {
    param([int]$Port)

    if ($Port -eq 0) {
        $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $tcp.Start()
        $Port = $tcp.LocalEndpoint.Port
        $tcp.Stop()
    }

    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://localhost:$Port/"
    try {
        $listener.Prefixes.Add($prefix)
    } catch {
        throw "Unable to register listener prefix $prefix. Try running as Administrator."
    }

    try {
        $listener.Start()
    } catch [System.Net.HttpListenerException] {
        if ($_.Exception.ErrorCode -eq 5) {
            $netsh = "netsh http add urlacl url=http://+:$Port/ user=Everyone"
            throw "Access denied reserving $prefix. Run PowerShell as Administrator, then run: $netsh"
        }
        if ($_.Exception.ErrorCode -eq 183) {
            throw "Port $Port already in use. Pick another with -Port."
        }
        throw "HttpListener failed to start on $prefix: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{ Listener = $listener; Port = $Port }
}

function Get-MatlabStatus {
    $matlabCmd = Get-Command matlab -ErrorAction SilentlyContinue
    if ($null -eq $matlabCmd) {
        $obj = [PSCustomObject]@{
            Label = 'MATLAB'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $false
        }
        Write-Log -Message "MATLAB not detected"
        return $obj
    }

    $obj = [PSCustomObject]@{
        Label = 'MATLAB'
        Emoji = '✅'
        Value = "Found (`$($matlabCmd.Source)`), latest known $latestMatlabRelease"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
    }
    Write-Log -Message "MATLAB detected at $($matlabCmd.Source)"
    return $obj
}

function Get-JavaStatus {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $javaCmd) {
        $obj = [PSCustomObject]@{
            Label = 'Java JDK'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://www.oracle.com/java/technologies/downloads/'
            WingetId = 'Microsoft.OpenJDK.17'
        }
        Write-Log -Message "Java not detected" -Level 'WARN'
        return $obj
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
        Write-Log -Message "Java version parse failed: $version" -Level 'WARN'
    } elseif ($parsedVersion -lt [version]'1.8') {
        $emoji = '⚠️'
        $color = [ConsoleColor]::Yellow
        $needsDownload = $true
        Write-Log -Message "Java outdated: $parsedVersion" -Level 'WARN'
    } else {
        Write-Log -Message "Java detected: $parsedVersion"
    }

    $obj = [PSCustomObject]@{
        Label = 'Java JDK'
        Emoji = $emoji
        Value = "Detected ($version)"
        Color = $color
        NeedsDownload = $needsDownload
        DownloadUrl = 'https://www.oracle.com/java/technologies/downloads/'
        WingetId = 'Microsoft.OpenJDK.17'
    }
    return $obj
}

function Get-DotNetStatus {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $dotnetCmd) {
        $obj = [PSCustomObject]@{
            Label = '.NET Runtime'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://dotnet.microsoft.com/en-us/download/dotnet'
            WingetId = 'Microsoft.DotNet.Runtime.8'
        }
        Write-Log -Message ".NET runtime not detected" -Level 'WARN'
        return $obj
    }

    $version = (dotnet --version 2>&1 | Select-Object -First 1)
    Write-Log -Message ".NET runtime detected: $version"
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
        $obj = [PSCustomObject]@{
            Label = 'C/C++ Compiler'
            Emoji = '❌'
            Value = 'None detected (add MSVC, GCC, or Clang)'
            Color = [ConsoleColor]::Red
            NeedsDownload = $true
            DownloadUrl = 'https://visualstudio.microsoft.com/visual-cpp-build-tools/'
            WingetId = 'Microsoft.VisualStudio.2022.BuildTools'
        }
        Write-Log -Message "Compiler missing" -Level 'WARN'
        return $obj
    }

    $obj = [PSCustomObject]@{
        Label = 'C/C++ Compiler'
        Emoji = '✅'
        Value = "Detected: $($found -join ', ')"
        Color = [ConsoleColor]::Green
        NeedsDownload = $false
        DownloadUrl = 'https://visualstudio.microsoft.com/visual-cpp-build-tools/'
        WingetId = 'Microsoft.VisualStudio.2022.BuildTools'
    }
    Write-Log -Message "Compiler(s) detected: $($found -join ', ')"
    return $obj
}

function Invoke-AutoInstall {
    param([PSCustomObject]$Status)

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { return $false }
    if (-not $Status.WingetId) { return $false }

    Write-Host "Attempting silent install via winget for $($Status.Label)..." -ForegroundColor Cyan
    Write-Log -Message "Starting winget install for $($Status.Label) ($($Status.WingetId))"
    try {
        winget install --silent --accept-source-agreements --accept-package-agreements $Status.WingetId
        Write-Log -Message "winget install succeeded for $($Status.Label)"
        return $true
    } catch {
        Write-Host "winget install failed. Opening the download page instead." -ForegroundColor Yellow
        Write-Log -Message "winget install failed for $($Status.Label): $($_.Exception.Message)" -Level 'WARN'
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
        Write-Log -Message "winget finished for $($Status.Label)"
    }

    if ($autoInstalled) { return }

    $response = Read-Host "Open the official $($Status.Label) download page now? (Y/N, default Y)"
    if ([string]::IsNullOrWhiteSpace($response) -or $response.Trim().ToUpper() -eq 'Y') {
        try {
            Start-Process $Status.DownloadUrl | Out-Null
            Write-Log -Message "Opened download page for $($Status.Label): $($Status.DownloadUrl)"
        } catch {
            Write-Host "Couldn't launch browser. Please open: $($Status.DownloadUrl)" -ForegroundColor Yellow
            Write-Log -Message "Failed to open download page for $($Status.Label): $($_.Exception.Message)" -Level 'WARN'
        }
    } else {
        Write-Log -Message "User skipped download for $($Status.Label)"
    }
}

function Open-LogFolder {
    try {
        if (-not (Test-Path $script:LogDirectory)) { New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null }
        Start-Process $script:LogDirectory | Out-Null
        Write-Host "Log folder opened: $script:LogDirectory" -ForegroundColor Gray
        Write-Log -Message "Opened log folder"
    } catch {
        Write-Host "Logs live at: $script:LogDirectory" -ForegroundColor Yellow
        Write-Log -Message "Failed to open log folder: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Start-Dashboard {
    param([int]$Port)

    $dashboardHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MATLAB Requirement Checker</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #0b1021;
      --panel: #11162b;
      --accent: #70d6ff;
      --accent-2: #d83f87;
      --text: #e9ecf5;
      --muted: #9ba4c4;
      --success: #4ade80;
      --warn: #f5c15c;
      --danger: #f87171;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: radial-gradient(circle at 10% 20%, #1d2340, #0b1021 35%),
                  radial-gradient(circle at 90% 10%, #192547, #0b1021 35%);
      font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
      color: var(--text);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 32px 16px;
    }
    .shell {
      width: min(1200px, 100%);
      background: linear-gradient(145deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
      border: 1px solid rgba(255,255,255,0.08);
      box-shadow: 0 20px 80px rgba(0,0,0,0.45);
      border-radius: 18px;
      padding: 28px 32px 36px;
      backdrop-filter: blur(8px);
    }
    header {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
    }
    h1 {
      margin: 0;
      font-weight: 700;
      letter-spacing: 0.4px;
      font-size: clamp(22px, 2vw + 12px, 32px);
      display: flex;
      gap: 10px;
      align-items: center;
    }
    h1 span.badge {
      background: rgba(255,255,255,0.06);
      padding: 6px 10px;
      border-radius: 10px;
      font-size: 12px;
      color: var(--muted);
      border: 1px solid rgba(255,255,255,0.08);
    }
    .actions {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    button {
      cursor: pointer;
      border: none;
      border-radius: 12px;
      padding: 11px 16px;
      font-size: 14px;
      font-weight: 600;
      color: var(--text);
      background: linear-gradient(135deg, var(--accent), #66b3ff);
      box-shadow: 0 8px 30px rgba(112, 214, 255, 0.25);
      transition: transform 120ms ease, box-shadow 120ms ease, filter 120ms ease;
    }
    button.secondary {
      background: rgba(255,255,255,0.05);
      box-shadow: inset 0 0 0 1px rgba(255,255,255,0.08);
    }
    button:active { transform: translateY(1px); }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 14px;
      margin-top: 18px;
    }
    .card {
      background: var(--panel);
      border-radius: 16px;
      padding: 16px;
      border: 1px solid rgba(255,255,255,0.06);
      box-shadow: 0 10px 30px rgba(0,0,0,0.35);
      transition: transform 160ms ease, border-color 160ms ease;
      position: relative;
      overflow: hidden;
    }
    .card::after {
      content: "";
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at 20% 10%, rgba(255,255,255,0.05), transparent 35%);
      pointer-events: none;
    }
    .card:hover { transform: translateY(-2px); border-color: rgba(112,214,255,0.35); }
    .card header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 8px;
    }
    .emoji {
      font-size: 26px;
      width: 32px;
      text-align: center;
    }
    .title {
      font-weight: 700;
      font-size: 16px;
    }
    .value { color: var(--muted); font-size: 13px; }
    .download-link {
      margin-top: 10px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      color: var(--accent);
      text-decoration: none;
      font-weight: 600;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.2px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.08);
      color: var(--muted);
    }
    .pill.success { color: var(--success); border-color: rgba(74,222,128,0.35); }
    .pill.warn { color: var(--warn); border-color: rgba(245,193,92,0.35); }
    .pill.danger { color: var(--danger); border-color: rgba(248,113,113,0.35); }
    .footer {
      margin-top: 20px;
      color: var(--muted);
      font-size: 12px;
      text-align: right;
    }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <h1>⚡ MATLAB Requirement Checker <span class="badge">No MATLAB needed</span></h1>
      <div class="actions">
        <button id="scan-all">Scan all</button>
        <button class="secondary" id="refresh">Refresh cards</button>
      </div>
    </header>
    <div class="grid">
      <div class="card" id="card-windows">
        <header><div class="emoji">🪟</div><div class="title">Windows</div></header>
        <div class="value">Detecting your edition…</div>
        <div class="pill">Environment</div>
      </div>
      <div class="card" id="card-matlab">
        <header><div class="emoji">⏳</div><div class="title">MATLAB</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-java">
        <header><div class="emoji">⏳</div><div class="title">Java JDK</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-dotnet">
        <header><div class="emoji">⏳</div><div class="title">.NET Runtime</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-compiler">
        <header><div class="emoji">⏳</div><div class="title">C/C++ Compiler</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-internet">
        <header><div class="emoji">⏳</div><div class="title">Internet</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-disk">
        <header><div class="emoji">⏳</div><div class="title">System Disk</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-memory">
        <header><div class="emoji">⏳</div><div class="title">Memory</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-winget">
        <header><div class="emoji">⏳</div><div class="title">winget</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
      <div class="card" id="card-update">
        <header><div class="emoji">⏳</div><div class="title">Windows Update</div></header>
        <div class="value">Waiting for scan…</div>
        <div class="pill">Not yet scanned</div>
      </div>
    </div>
    <div class="footer">Uses built-in Windows tools only. Logs live in %USERPROFILE%\\Logs\\MatlabRequirementChecker.</div>
  </div>
  <script>
    const map = {
      windows: 'Windows',
      matlab: 'MATLAB',
      java: 'Java JDK',
      dotnet: '.NET',
      compiler: 'C/C++ Compiler',
      internet: 'Internet',
      disk: 'System Disk',
      memory: 'Memory',
      winget: 'winget',
      update: 'Windows Update'
    };

    function pillClass(emoji) {
      if (emoji === '✅' || emoji === '🪟') return 'pill success';
      if (emoji === '⚠️') return 'pill warn';
      return 'pill danger';
    }

    function setCard(key, payload) {
      const card = document.querySelector(`#card-${key}`);
      if (!card) return;
      card.querySelector('.emoji').textContent = payload.Emoji || '⏳';
      card.querySelector('.title').textContent = payload.Label;
      card.querySelector('.value').textContent = payload.Value;
      const pill = card.querySelector('.pill');
      pill.className = pillClass(payload.Emoji);
      pill.textContent = payload.NeedsDownload ? 'Needs download' : 'Ready';

      let link = card.querySelector('.download-link');
      if (payload.NeedsDownload && payload.DownloadUrl) {
        if (!link) {
          link = document.createElement('a');
          link.className = 'download-link';
          link.target = '_blank';
          link.rel = 'noreferrer noopener';
          link.innerText = 'Get the latest →';
          card.appendChild(link);
        }
        link.href = payload.DownloadUrl;
        link.style.display = 'inline-flex';
      } else if (link) {
        link.style.display = 'none';
      }
    }

    async function call(path) {
      const res = await fetch(path);
      if (!res.ok) throw new Error('Request failed');
      return res.json();
    }

    async function scanAll() {
      const data = await call('/api/scan/all');
      data.items.forEach(item => {
        const key = Object.keys(map).find(k => map[k] === item.Label) || item.Label.toLowerCase();
        setCard(key, item);
      });
    }

    function singleScan(key) {
      call(`/api/scan/${key}`).then(setCard.bind(null, key)).catch(console.error);
    }

    document.getElementById('scan-all').addEventListener('click', scanAll);
    document.getElementById('refresh').addEventListener('click', scanAll);

    scanAll();

    document.addEventListener('keydown', (e) => {
      const keyMap = { '1': 'matlab', '2': 'java', '3': 'dotnet', '4': 'compiler', '5': 'internet', '6': 'disk', '7': 'memory', '8': 'winget', '9': 'update', 'a': 'all' };
      const key = keyMap[e.key.toLowerCase()];
      if (!key) return;
      if (key === 'all') { scanAll(); return; }
      singleScan(key);
    });
  </script>
</body>
</html>
"@

    $listenerInfo = New-Listener -Port $Port
    $listener = $listenerInfo.Listener
    $Port = $listenerInfo.Port

    Write-Host "Serving the dashboard at http://localhost:$Port/" -ForegroundColor Cyan
    Write-Log -Message "Dashboard listening on http://localhost:$Port/"

    try {
        Start-Process "http://localhost:$Port/" | Out-Null
    } catch {
        Write-Host "Browser launch blocked; open http://localhost:$Port/ manually." -ForegroundColor Yellow
    }

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $path = $context.Request.Url.AbsolutePath.Trim('/').ToLower()

            switch ($path) {
                '' { Write-Response -Response $context.Response -Body $dashboardHtml -ContentType 'text/html; charset=utf-8'; Log-Request -Path '/' }
                'api/scan/all' { Send-Json -Response $context.Response -Data @{ items = Get-AllPayloads }; Log-Request -Path $path }
                'api/scan/windows' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-WindowsStatus)); Log-Request -Path $path }
                'api/scan/matlab' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-MatlabStatus)); Log-Request -Path $path }
                'api/scan/java' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-JavaStatus)); Log-Request -Path $path }
                'api/scan/dotnet' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-DotNetStatus)); Log-Request -Path $path }
                'api/scan/compiler' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-CompilerStatus)); Log-Request -Path $path }
                'api/scan/internet' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-InternetStatus)); Log-Request -Path $path }
                'api/scan/disk' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-DiskStatus)); Log-Request -Path $path }
                'api/scan/memory' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-MemoryStatus)); Log-Request -Path $path }
                'api/scan/winget' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-WingetStatus)); Log-Request -Path $path }
                'api/scan/update' { Send-Json -Response $context.Response -Data (Get-StatusPayload (Get-WindowsUpdateStatus)); Log-Request -Path $path }
                Default { Write-Response -Response $context.Response -Body 'Not found' -StatusCode 404; Log-Request -Path $path -Status 404 }
            }
        }
    }
    finally {
        if ($listener.IsListening) { $listener.Stop() }
        $listener.Close()
    }
}

function Launch-Dashboard {
    $args = @('-File', $PSCommandPath, '-Dashboard', '-Port', $Port, '-LogPath', $script:LogDirectory, '-LogFile', $script:LogFile)
    try {
        Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden | Out-Null
        Write-Host "Dashboard is starting in your browser." -ForegroundColor Cyan
        Write-Log -Message "Dashboard launched from menu"
    } catch {
        Write-Host "Couldn't start the dashboard: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Log -Message "Dashboard launch failed: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Save-SupportBundle {
    try {
        if (-not (Test-Path $script:LogDirectory)) { New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null }
        $bundle = Join-Path $script:LogDirectory "checker-support-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        $logFiles = Get-ChildItem $script:LogDirectory -Filter '*.txt' -ErrorAction SilentlyContinue
        if (-not $logFiles) {
            Write-Host "No logs yet. Run a scan first." -ForegroundColor Yellow
            Write-Log -Message "Support bundle skipped: no logs" -Level 'WARN'
            return
        }

        Compress-Archive -Path $logFiles.FullName -DestinationPath $bundle -Force
        Write-Host "Saved bundle: $bundle" -ForegroundColor Green
        Write-Log -Message "Created support bundle at $bundle"
    } catch {
        Write-Host "Could not create support bundle: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Message "Support bundle failed: $($_.Exception.Message)" -Level 'ERROR'
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
    Write-Host "  [8] Winget" -ForegroundColor DarkCyan
    Write-Host "  [9] Windows Update" -ForegroundColor DarkCyan
    Write-Host "  [D] Launch web dashboard" -ForegroundColor Cyan
    Write-Host "  [L] Open log folder" -ForegroundColor DarkGray
    Write-Host "  [B] Save support bundle (.zip)" -ForegroundColor DarkGray
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
        '8' { Show-Result (Get-WingetStatus) }
        '9' { Show-Result (Get-WindowsUpdateStatus) }
        'D' { Launch-Dashboard }
        'L' { Open-LogFolder }
        'B' { Save-SupportBundle }
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
    Write-Log -Message "Displayed result for $($Status.Label): $($Status.Value)"
    if (-not $ScanAll) {
        Offer-Download -Status $Status
    }
}

function Run-AllChecks {
    Write-Host ""
    Write-Log -Message "Running Scan All"
    Show-Result (Get-WindowsStatus)
    Show-Result (Get-MatlabStatus)
    Show-Result (Get-JavaStatus)
    Show-Result (Get-DotNetStatus)
    Show-Result (Get-CompilerStatus)
    Show-Result (Get-InternetStatus)
    Show-Result (Get-DiskStatus)
    Show-Result (Get-MemoryStatus)
    Show-Result (Get-WingetStatus)
    Show-Result (Get-WindowsUpdateStatus)
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
        Get-WingetStatus
        Get-WindowsUpdateStatus
    )
}

# Skip interactive entry when dot-sourced for reuse by other scripts
try {
    if ($Dashboard) {
        try {
            Start-Dashboard -Port $Port
        } catch {
            Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Message "Dashboard failed: $($_.Exception.Message)" -Level 'ERROR'
            return
        }
        return
    }

    if ($MyInvocation.InvocationName -ne '.') {
        if ($ScanAll) {
            Run-AllChecks
            if (-not $Quiet) {
                Write-Host ""
                Write-Host "Done." -ForegroundColor Green
            }
            return
        }

        Show-Checks
    }
}
finally {
    if ($script:TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}
