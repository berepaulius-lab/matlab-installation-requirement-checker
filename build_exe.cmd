@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if not exist node_modules (echo Installing local tools... & npm install)

if errorlevel 1 (
  echo npm install failed. Install Node.js then re-run this script.
  exit /b 1
)

echo Building standalone checker.exe (Node 18 target)...
npx pkg checker.js --targets node18-win-x64 --output checker.exe
if errorlevel 1 (
  echo Build failed. Ensure Node.js and npm are installed.
  exit /b 1
)

echo Done. checker.exe is ready beside run_checker.cmd.
endlocal
