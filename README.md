# Windows Requirement Checker (one-click, self-contained)

Double-click **run_checker.cmd** (or **checker.exe** if you already built it). The launcher immediately creates a
numbered log file in the local **logs** folder and prints the path so you can watch everything being recorded. From
there it does the work itself: it builds **checker.exe** if possible (with a visible spinner, heartbeat messages, and
a 4-minute timeout), or grabs a portable Node runtime, or falls back to batch. When the checks finish, the window stays
open until you press Enter so you always see the results and log path.

## How it runs (no extra setup)
1. Create `logs/log-###.txt` beside the launcher and mirror all console output there (first thing that happens).
2. If **checker.exe** is present, run it. If not, the launcher auto-builds it with `npm`/`pkg` when available, showing
   a spinner so you know it’s working and timing out cleanly if it takes too long.
3. If no exe exists, automatically download a portable Node.js runtime (saved under **runtime/**) with built-in
   `curl`/`tar` and run `checker.js` through it.
4. If every runtime option fails, fall back to a minimal batch-only checker so you still get results in the same log
   file.

## What it checks and can auto-fix (Node/EXE path)
- Windows version and architecture.
- Internet reachability to neutral hosts (no sign-in required).
- Java JDK, .NET, and C/C++ compiler presence.
- Disk free space on C: and available memory.
- If something is missing, the checker asks once: type **Y** and it will try to download/install Java, .NET, and MSVC
  Build Tools silently using built-in `curl`/`msiexec`/`winget`.

## Logs you can hand to support
- Every run writes to `logs/log-###.txt` next to the launcher; open it with Notepad to review.
- The log prints which runtime was used (EXE, portable Node, or batch fallback), every check, and any install attempts.

## Build or refresh checker.exe (optional)
The launcher already tries to build it. If you prefer to do it yourself:
1. Install Node.js 18+.
2. Open Command Prompt in this folder.
3. Run `build_exe.cmd` to produce **checker.exe** using `pkg`.
4. Re-run **run_checker.cmd**; it will now pick up the EXE first.

## Package for sharing (optional)
- `package_windows_checker.ps1` zips the launcher, Node script, optional EXE, runtime folder (if downloaded), and logs
  folder. Run from PowerShell on Windows: `powershell -ExecutionPolicy Bypass -File package_windows_checker.ps1`.

## Files
- `run_checker.cmd` – one-click launcher that logs first, auto-builds **checker.exe** when it can, prefers the exe,
  auto-downloads portable Node, and falls back to batch checks if all else fails.
- `checker.js` – Node-based checker with one-key auto-fix prompts and a stay-open exit prompt.
- `checker.exe` – optional packaged binary produced by `build_exe.cmd` (or automatically by the launcher).
- `runtime/` – created automatically when the launcher downloads a portable Node runtime.
- `logs/` – ready-made folder where log files are created (window stays open so you can note the path).
- `build_exe.cmd` – helper to build `checker.exe` with `pkg`.
- `package_windows_checker.ps1` – helper to zip the above for distribution.
