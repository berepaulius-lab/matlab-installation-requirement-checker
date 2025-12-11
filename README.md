# Windows Requirement Checker (one-click, self-contained)

Double-click **run_checker.cmd** (or **checker.exe** if it already exists). The launcher immediately creates a numbered
log in the local **logs** folder, prints where it is, and starts working. It runs the checker right away while quietly
building **checker.exe** in the background for next time, so you aren’t stuck watching a build. If it can’t build, it
grabs a portable Node runtime, and if that fails it still falls back to a tiny batch checker. When everything finishes,
the window stays open until you press Enter.

The checker runs in **hands-free** mode: scans start immediately, the spinner shows background work, and auto-fixes
proceed without extra keystrokes. Just double-click and watch the log updates.

## How it runs (no extra setup)
1. Create `logs/log-###.txt` beside the launcher and mirror all console output there (first thing that happens).
2. If **checker.exe** is present, run it. If not, fire up the checker immediately and start a background build of the
   exe (with a visible spinner and timeout) so the current run isn’t delayed.
3. If no exe exists and npm/pkg aren’t available, automatically download a portable Node.js runtime (saved under
   **runtime/**) with built-in `curl`/`tar` and run `checker.js` through it.
4. If every runtime option fails, fall back to a minimal batch-only checker so you still get results in the same log
   file.

## What it checks and can auto-fix (Node/EXE path)
- Windows version and architecture.
- Internet reachability to neutral hosts (no sign-in required).
- Java JDK, .NET, and C/C++ compiler presence.
- Disk free space on C: and available memory.
- If something is missing, the checker automatically attempts to download/install Java, .NET, and MSVC Build Tools
  silently using built-in `curl`/`msiexec`/`winget` (auto-approve when launched from **run_checker.cmd**).

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
- `run_checker.cmd` – one-click launcher that logs first, auto-builds **checker.exe** when it can (with a spinner),
  prefers the exe, auto-downloads portable Node, and falls back to batch checks if all else fails.
- `checker.js` – Node-based checker with auto-start/auto-fix support and a stay-open exit prompt.
- `checker.exe` – optional packaged binary produced by `build_exe.cmd` (or automatically by the launcher).
- `runtime/` – created automatically when the launcher downloads a portable Node runtime.
- `logs/` – ready-made folder where log files are created (window stays open so you can note the path).
- `build_exe.cmd` – helper to build `checker.exe` with `pkg`.
- `package_windows_checker.ps1` – helper to zip the above for distribution.
