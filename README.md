# One-click Windows 11 Requirement Checker (no MATLAB needed)

Drop this folder on a Windows 11 PC and double-click **run_checker.cmd**. The script instantly creates a fresh log file under `logs/`, checks your setup, offers to fix missing pieces with winget when available, and can launch the flashy web dashboard with one key.

## How to run it
1) Double-click **run_checker.cmd** (or right-click → Run as Administrator if you expect permission prompts).
   - It immediately creates a fresh log file in `logs/` and tells you where to find it before continuing.
   - The menu appears with emojis. Press **A** then Enter to scan everything.
   - Press **D** to launch the web dashboard in your browser (served locally).
   - Press **L** to open the log folder or **B** to zip recent logs for support.
2) Need a silent run? From PowerShell:  
   `powershell -ExecutionPolicy Bypass -File requirements_checker.ps1 -ScanAll -LogPath .\logs`

## What it checks (and can auto-fix)
- Windows edition/build/architecture and PowerShell version (links to upgrade if outdated).
- winget readiness plus Windows Update service health (for smooth installs).
- MATLAB on PATH (no MATLAB runtime required to run this app).
- Java JDK, .NET runtime, and C/C++ compilers (`cl`, `gcc`, `clang`). Missing items attempt silent **winget** install first, then open the official download page.
- Bonus health: internet reachability, C: drive space, and available RAM.

## Logs first, always
- A `logs/` folder is created on launch, and a timestamped log starts **before** any checks run.
- The dashboard and the menu share the same log folder and log file (passed from the launcher).
- Use **L** in the menu to jump to the folder, or **B** to package recent logs into a ZIP for sharing.

## Packaging a “download me” zip on Windows
1. Open PowerShell in this folder.
2. Run `./package_windows_checker.ps1`.
3. Share the generated `requirements-checker-windows.zip` (it includes the launcher, script, docs, and an empty `logs` folder).

## Troubleshooting
- **PowerShell missing?** The launcher tells you where to download it. Install, then rerun the launcher.
- **Dashboard port busy?** Run `run_checker.cmd` and press **D**, or from PowerShell: `powershell -File requirements_checker.ps1 -Dashboard -Port 0` to auto-pick a free port.
- **Winget blocked?** The script falls back to opening the official download pages so you can install manually.
