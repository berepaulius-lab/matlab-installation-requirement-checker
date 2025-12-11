#requires -Version 5.1
<#+
.SYNOPSIS
    Launches a local HTML dashboard with CSS-styled cards and buttons to run requirement checks.

.DESCRIPTION
    Uses only built-in Windows 11 PowerShell/.NET to host a lightweight HTTP listener on localhost
    and serve a modern-looking dashboard. Buttons trigger the same checks as requirements_checker.ps1
    and instantly update the emoji status cards. No MATLAB or extra dependencies required.
#>

param(
    [int]$Port = 5133,
    [string]$LogPath,
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'

# Keep logs consistent with the CLI run
$script:LogDirectory = if ($LogPath) { $LogPath } else { Join-Path $PSScriptRoot 'logs' }
$script:LogFile = if ($LogFile) { $LogFile } else { Join-Path $script:LogDirectory "dashboard-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" }
if (-not (Test-Path $script:LogDirectory)) { New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null }
if ($script:LogFile -and -not (Test-Path $script:LogFile)) { "[INFO] $(Get-Date -Format o) :: Dashboard session started" | Out-File -FilePath $script:LogFile -Encoding UTF8 -Force }

# Reuse the core detection logic without triggering the CLI menu
. "$PSScriptRoot/requirements_checker.ps1"

function Ensure-Environment {
    if (-not $IsWindows) {
        throw "This dashboard is Windows-only."
    }

    if ($PSVersionTable.PSVersion -lt $minPowershell) {
        throw "PowerShell $minPowershell or newer is required. Current: $($PSVersionTable.PSVersion)."
    }

    Write-Log -Message "Environment check passed for dashboard: PS $($PSVersionTable.PSVersion), Port $Port"
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
        <header><div class="emoji">⏳</div><div class="title">Disk space</div></header>
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
    <div class="footer">Buttons call the built-in PowerShell checks and update instantly. Ctrl+C in the console to close the server.</div>
  </div>
  <script>
    const map = {
      windows: 'Windows',
      matlab: 'MATLAB',
      java: 'Java JDK',
      dotnet: '.NET Runtime',
      compiler: 'C/C++ Compiler',
      internet: 'Internet',
      disk: 'System Disk',
      memory: 'Memory',
      winget: 'winget',
      update: 'Windows Update'
    };

    function pillClass(emoji) {
      if (emoji.includes('✅')) return 'pill success';
      if (emoji.includes('⚠')) return 'pill warn';
      return 'pill danger';
    }

    function setCard(key, payload) {
      const card = document.getElementById(`card-${key}`);
      if (!card) return;
      card.querySelector('.emoji').textContent = payload.Emoji;
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

    // Initial sweep on load
    scanAll();

    // Optional keyboard shortcuts
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

try {
    Ensure-Environment

    $listenerInfo = New-Listener -Port $Port
    $listener = $listenerInfo.Listener
    $Port = $listenerInfo.Port

    Write-Host "Serving the CSS dashboard at http://localhost:$Port/" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
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
catch {
    Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
    Write-Log -Message "Dashboard failed: $($_.Exception.Message)" -Level 'ERROR'
    if ($listener -and $listener.IsListening) { $listener.Stop(); $listener.Close() }
    exit 1
}
