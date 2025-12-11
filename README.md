# Windows 11 Requirement Checker (no MATLAB needed)

Emoji-ready helper that checks MATLAB-related prerequisites using only built-in Windows tools (PowerShell and Command Prompt). No MATLAB installation is required. You get both a CSS dashboard and a simple menu.

## Quick start (easy mode)
1) Double-click **start_dashboard.cmd**
   - If PowerShell is missing, the launcher tells you where to get it.
   - Your browser opens with clean cards for Windows, MATLAB, Java, .NET, compiler + bonus internet/disk/memory.
   - Hit **Scan all**. Buttons update each card live.

2) Prefer the menu? Double-click **requirements_checker.cmd**
   - Press **A + Enter** to scan everything, or pick a number.
   - If something is missing, the script offers to open the official download page for you.

Silent terminal run (optional):

```powershell
powershell -ExecutionPolicy Bypass -File requirements_checker.ps1 -ScanAll
```

## Make a "download me" zip on Windows
1. Open PowerShell in this folder.
2. Run:
   ```powershell
   ./package_windows_checker.ps1
   ```
3. Share `requirements-checker-windows.zip`. It holds the two launchers plus this README and the short START_HERE guide.

## What the checks cover
- MATLAB presence on `PATH` (no MATLAB runtime required to run the checker).
- Java JDK detection with smart version parsing and install links.
- .NET runtime detection (needed for MATLAB Compiler SDK .NET assemblies).
- Supported compiler detection (MSVC `cl`, `gcc`, or `clang`).
- Bonus health checks: internet reachability, C: drive free space, and available RAM.

## Cleanup note (less clutter)
- All legacy MATLAB build helpers now live in `legacy-matlab/` so it’s obvious they’re optional.
- The only files you need to click on Windows are: `start_dashboard.cmd` / `requirements_dashboard.ps1` (HTML UI) and `requirements_checker.cmd` / `requirements_checker.ps1` (menu / silent scans).

## Troubleshooting (plain language)
- See red text? Rerun as Administrator once, then try again.
- If a card says it needs a download, pick **Yes** when the script offers to open the official site.
- If the dashboard complains about the port, run `start_dashboard.cmd -Port 0` to auto-pick a free port. As a last resort, run once as Administrator and execute:
  ```
  netsh http add urlacl url=http://+:5133/ user=Everyone
  ```
