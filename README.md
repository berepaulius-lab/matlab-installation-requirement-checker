# Windows 11 Requirement Checker (no MATLAB needed)

Zero-MATLAB, zero-setup checker with emoji results. It uses only built-in Windows (PowerShell + CMD) and will try to auto-install missing pieces with **winget** when possible. Two entry points: a glossy CSS dashboard and a simple keyboard menu.

## If you only read one thing
1) Double-click **start_dashboard.cmd** (opens your browser). Hit **Scan all**.
2) Or double-click **requirements_checker.cmd** for the menu. Press **A + Enter**.
3) When something is missing, the app first tries a silent winget install. If that’s not available, it offers to open the official download page.

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
3. Share `requirements-checker-windows.zip`. It holds both launchers plus the short START_HERE guide.

## What the checks cover
- Windows + PowerShell version badge (with upgrade link if outdated).
- MATLAB presence on `PATH` (no MATLAB runtime required to run the checker).
- Java JDK detection with smart version parsing and install/winget links.
- .NET runtime detection (needed for MATLAB Compiler SDK .NET assemblies).
- Supported compiler detection (MSVC `cl`, `gcc`, or `clang`) with winget auto-install for MSVC Build Tools.
- Bonus health checks: internet reachability, C: drive free space, and available RAM.

## Less clutter on disk
- MATLAB build helpers live in `legacy-matlab/` so it’s obvious they’re optional.
- The only Windows entry points: `start_dashboard.cmd` / `requirements_dashboard.ps1` (dashboard) and `requirements_checker.cmd` / `requirements_checker.ps1` (menu / silent scans).

## Troubleshooting (plain language)
- See red text? Rerun once as Administrator, then try again.
- Dashboard won’t start? Run `start_dashboard.cmd -Port 0` to auto-pick a free port. As a last resort, run once as Administrator and execute:
  ```
  netsh http add urlacl url=http://+:5133/ user=Everyone
  ```
- No winget? The scripts still open the official download pages so you can install manually.
