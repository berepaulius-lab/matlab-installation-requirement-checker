# Windows 11 Requirement Checker (no MATLAB needed)

A single folder that works on a fresh Windows 11 box: double-click a CMD, see emojis, get automatic fixes (winget when available), and keep logs you can zip up and share.

## Quick start (2 options)
- **Pretty dashboard:** double-click `start_dashboard.cmd`, then click **Scan all**. Cards update live in your browser.
- **Keyboard menu:** double-click `requirements_checker.cmd`, then press **A + Enter**. Extras include opening the log folder or saving a support bundle ZIP.

Optional silent run:

```powershell
powershell -ExecutionPolicy Bypass -File requirements_checker.ps1 -ScanAll -LogPath .\logs
```

## What gets checked (and fixed)
- Windows edition + build + PowerShell version, with a link to update PowerShell if needed.
- Winget availability (so auto-installs can succeed) and Windows Update service health.
- MATLAB on `PATH` (no MATLAB runtime required to run the checker itself).
- Java JDK (version-parsed), .NET runtime, and C/C++ compilers (`cl`, `gcc`, `clang`). Missing pieces trigger silent **winget** installs when possible, then fall back to the official download page.
- Bonus system health: internet reachability, C: drive free space, and available RAM.

## Logs and support bundles
- Every run writes a timestamped log under `logs/` (created automatically).
- In the menu, press **L** to open the log folder or **B** to save a ZIP bundle of recent logs for easy sharing.
- The dashboard reuses the same log folder so both entry points capture what happened.

## Make a “download me” zip on Windows
1. Open PowerShell in this folder.
2. Run `./package_windows_checker.ps1`.
3. Share `requirements-checker-windows.zip`. It includes both launchers, the docs, and a ready-made `logs` folder.

## Less clutter on disk
- MATLAB build helpers stay in `legacy-matlab/` and are ignored by default.
- The only Windows entry points you need: `start_dashboard.cmd` / `requirements_dashboard.ps1` (dashboard) and `requirements_checker.cmd` / `requirements_checker.ps1` (menu / silent scans).

## Troubleshooting (plain language)
- Red text on startup? Rerun as Administrator once, then try again.
- Dashboard won’t start? Run `start_dashboard.cmd -Port 0` to auto-pick a free port. If HTTP permissions block it, run once as Administrator and execute:
  ```
  netsh http add urlacl url=http://+:5133/ user=Everyone
  ```
- No winget? The scripts still offer the official download links so you can install manually.
