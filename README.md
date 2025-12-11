# Windows Requirement Checker (one-click, self-contained)

Double-click **run_checker.cmd** from Command Prompt. The launcher immediately creates a numbered log file in the local
**logs** folder, then runs the richest checker available automatically—no decisions needed. When the checks finish, the
window waits for you to press Enter so you always see the results and know where the log lives.

## How it runs (no extra setup)
1. Create `logs/log-###.txt` beside the launcher and mirror all console output there (first thing that happens).
2. If **checker.exe** is present, run it.
3. Otherwise, automatically download a portable Node.js runtime (saved under **runtime/**) with built-in `curl`/`tar`
   and run `checker.js` through it.
4. If the download fails or no runtime can be found, fall back to a minimal batch-only checker so you still get results
   in the same log file.

## What it checks (Node/EXE path)
- Windows version and architecture.
- Internet reachability to neutral hosts (no sign-in required).
- Java JDK, .NET, and C/C++ compiler presence.
- Disk free space on C: and available memory.

## Logs you can hand to support
- Every run writes to `logs/log-###.txt` next to the launcher; open it with Notepad to review.
- The log prints which runtime was used (EXE, portable Node, or batch fallback) plus every check result.

## Build or refresh checker.exe (optional)
1. Install Node.js 18+.
2. Open Command Prompt in this folder.
3. Run `build_exe.cmd` to produce **checker.exe** using `pkg`.
4. Re-run **run_checker.cmd**; it will now pick up the EXE first.

## Package for sharing (optional)
- `package_windows_checker.ps1` zips the launcher, Node script, optional EXE, runtime folder (if downloaded), and logs
  folder. Run from PowerShell on Windows: `powershell -ExecutionPolicy Bypass -File package_windows_checker.ps1`.

## Files
- `run_checker.cmd` – one-click launcher that logs first, prefers checker.exe, auto-downloads portable Node, and falls
  back to batch checks if all else fails.
- `checker.js` – Node-based checker used by the EXE/portable runtime.
- `checker.exe` – optional packaged binary produced by `build_exe.cmd`.
- `runtime/` – created automatically when the launcher downloads a portable Node runtime.
- `logs/` – ready-made folder where log files are created (window stays open so you can note the path).
- `build_exe.cmd` – helper to build `checker.exe` with `pkg`.
- `package_windows_checker.ps1` – helper to zip the above for distribution.
