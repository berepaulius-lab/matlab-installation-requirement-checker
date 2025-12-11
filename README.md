# Windows 11 Requirement Checker (no MATLAB needed)

Emoji-ready helper that checks MATLAB-related prerequisites using only built-in Windows tools (PowerShell and Command Prompt). No MATLAB installation is required. You now get both a colorful HTML dashboard **and** the classic menu/scan experience.

## Quick start (pick your flavor)
1) **Slick HTML dashboard (with CSS + buttons)**
   - Double-click `start_dashboard.cmd` (or run `powershell -ExecutionPolicy Bypass -File requirements_dashboard.ps1`).
   - The script now self-checks Windows/PowerShell first; if a permission or port issue appears, it tells you exactly how to fix it.
   - Your default browser opens a neon-styled dashboard with a Windows badge plus the core MATLAB/Java/.NET/compiler cards **and bonus health checks (internet, disk space, memory)**. Use **Scan all** or the per-card shortcuts to refresh statuses live.

2) **Classic menu / one-shot scan**  
   - Double-click `requirements_checker.cmd` (or right-click `requirements_checker.ps1` → **Run with PowerShell**).  
   - Press **A + Enter** to scan everything, or pick a specific check. Missing/outdated tools offer to open the official download page.

Silent terminal run is still available:

```powershell
powershell -ExecutionPolicy Bypass -File requirements_checker.ps1 -ScanAll
```

## Create a "download me" zip on Windows
1. Open PowerShell in this folder.
2. Run:
   ```powershell
   ./package_windows_checker.ps1
   ```
3. Share the generated `requirements-checker-windows.zip`. It contains the dashboard launcher, menu launcher, README, and `START_HERE.txt` with simplified steps.

## What the checks cover
- MATLAB presence on `PATH` (no MATLAB runtime required to run the checker).
- Java JDK detection with smart version parsing and install links.
- .NET runtime detection (needed for MATLAB Compiler SDK .NET assemblies).
- Supported compiler detection (MSVC `cl`, `gcc`, or `clang`).
- Bonus health checks: internet reachability, C: drive free space, and available RAM.

## Cleanup note (less clutter)
- All legacy MATLAB build helpers now live in `legacy-matlab/` so it’s obvious they’re optional.
- The only files you need to click on Windows are: `start_dashboard.cmd` / `requirements_dashboard.ps1` (HTML UI) and `requirements_checker.cmd` / `requirements_checker.ps1` (menu / silent scans).

## Troubleshooting
- If a check shows `⚠️` or `❌`, let the script open the official download page, install or add the tool to your `PATH`, then run **Scan All** again.
- Running from a network drive with restricted execution policies? Launch an elevated PowerShell and rerun with `-ExecutionPolicy Bypass`.
- If the dashboard reports it cannot reserve the localhost port, rerun as Administrator once and execute `netsh http add urlacl url=http://+:5133/ user=Everyone`, or start it on another port via `start_dashboard.cmd -Port 0`.
