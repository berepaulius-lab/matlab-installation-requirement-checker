@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"

rem Ensure PowerShell exists on the machine
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo.
  echo PowerShell is missing on this PC. Please install the latest Windows PowerShell from:
  echo   https://aka.ms/powershell-release?tag=stable
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_dashboard.ps1" -LogPath "%LOG_DIR%" %*
