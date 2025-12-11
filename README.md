# Windows 11 Requirement Checker (no MATLAB needed)

An emoji-forward helper that checks MATLAB-related prerequisites using only built-in Windows tools (PowerShell and Command Prompt). No MATLAB installation is required. Double-click `requirements_checker.cmd` or run the PowerShell script for a friendly menu with a **Scan All** option.

## Quick start (double-click friendly)
1. Download or clone this folder.
2. Double-click `requirements_checker.cmd` (or right-click `requirements_checker.ps1` and choose **Run with PowerShell**).
3. Press **A** then **Enter** for an instant scan, or pick an individual check from the menu.

You can also run silently from a terminal:

```powershell
powershell -ExecutionPolicy Bypass -File requirements_checker.ps1 -ScanAll
```

## Create a "download me" zip on Windows
1. Open PowerShell in this folder.
2. Run:
   ```powershell
   ./package_windows_checker.ps1
   ```
3. Share the generated `requirements-checker-windows.zip`. It contains the CMD launcher, PowerShell script, README, and `START_HERE.txt` with simplified steps.

## What the checks cover
- MATLAB presence on `PATH` (no MATLAB runtime required to run the checker).
- Java JDK detection (needs Java 8+ for MATLAB Compiler SDK Java packages).
- .NET runtime detection (needed for MATLAB Compiler SDK .NET assemblies).
- Supported compiler detection (MSVC `cl`, `gcc`, or `clang`).

## Troubleshooting
- If a check shows `⚠️` or `❌`, install or add the tool to your `PATH` and run **Scan All** again.
- Running from a network drive with restricted execution policies? Launch an elevated PowerShell and rerun with `-ExecutionPolicy Bypass`.
