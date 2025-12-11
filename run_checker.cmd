@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo.
  echo PowerShell is missing on this PC. Download and install the latest release from:
  echo   https://aka.ms/powershell-release?tag=stable
  pause
  exit /b 1
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\checker-%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"

echo Starting log in: %LOG_FILE%
echo (The PowerShell window will record everything shown on screen.)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_checker.ps1" -LogPath "%LOG_DIR%" -LogFile "%LOG_FILE%" %*
endlocal
