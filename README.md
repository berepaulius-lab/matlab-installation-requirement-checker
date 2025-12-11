# MATLAB Installation Requirement Checker

A one-click, emoji-forward helper that checks common MATLAB installation prerequisites. You can run it directly inside MATLAB or share a prepackaged zip that includes a built executable plus simple "Start Here" guidance.

## Pick your path
- **Fast scan in MATLAB:** run the UI or console snapshot directly from MATLAB.
- **Share a zip to end users:** build the executable once, create a zip bundle, and send the "download me" package so others can double-click and run.

## Quick start (MATLAB session)
1. Clone or unzip the repository.
2. In MATLAB, add the folder to your path and run one of the entry points:
   - UI dashboard: `requirements_checker_ui` (or run `launch_requirements_checker`).
   - Console snapshot: `quick_requirements_check`.
3. Click **Scan All** (UI) or read the console output to see emoji results for MATLAB, Java JDK, .NET runtime, and compiler availability, plus product-specific notes.

## Build a standalone executable
> Requires MATLAB Compiler and MATLAB Runtime for end users.

1. In MATLAB, run:
   ```matlab
   build_requirements_checker_exe(fullfile(pwd, 'dist'))
   ```
   This generates `requirements_checker` (or `requirements_checker.exe` on Windows) inside `dist`.
2. Double-click the executable to open the UI. End users only need the MATLAB Runtime.

## Create a "download me" zip bundle
> Perfect for sharing a ready-to-run package with non-MATLAB users.

1. Build the executable as above so `dist/` contains the generated app.
2. From MATLAB, create the distributable zip:
   ```matlab
   package_requirements_checker('dist', fullfile(pwd, 'requirements-checker-bundle.zip'))
   ```
3. Share `requirements-checker-bundle.zip`. Inside, users will find:
   - `START_HERE.txt` with step-by-step run instructions.
   - `requirements_checker` executable plus supporting files.
   - A copy of this README and source `.m` files (handy for MATLAB users).

## What the checks cover
- Installed MATLAB release vs. latest known release (currently `R2024b`).
- Java JDK detection (Java 8+ for MATLAB Compiler SDK Java packages).
- .NET runtime detection (needed for MATLAB Compiler SDK .NET assemblies).
- Supported compiler detection (required for Embedded/MATLAB/Simulink Coder and MATLAB Compiler add-ins).
- Highlights of product-specific requirements and hardware setup notes.

## Troubleshooting
- If a check shows `⚠️` or `❌`, click the individual **Scan** button or rerun the console snapshot to refresh.
- Ensure command-line tools (`java`, `javac`, `dotnet`) are on your system `PATH` for accurate detection.
- Rebuild the executable after updating MATLAB or its toolboxes to keep the packaged checks current.

