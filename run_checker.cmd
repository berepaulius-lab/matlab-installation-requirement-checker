@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"

rem Ensure logs exist and build a safe timestamp
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set "YY=%%d"& set "MM=%%b"& set "DD=%%c"
for /f "tokens=1-3 delims=:.," %%a in ("%time%") do set "HH=%%a"& set "MN=%%b"& set "SS=%%c"
set "HH=0%HH%"& set "HH=!HH:~-2!"
set "LOG_FILE=%LOG_DIR%\checker-!YY!!MM!!DD!-!HH!!MN!!SS!.log"

echo [INFO] Starting log in: %LOG_FILE%>"%LOG_FILE%"
echo (Everything printed to the screen will also be copied here.)>>"%LOG_FILE%"
echo Starting log in: %LOG_FILE%
echo (Everything printed to the screen will also be copied here.)

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [WARN] PowerShell not found. Trying to download it automatically...>>"%LOG_FILE%"
  echo PowerShell not found. Trying to download it automatically...
  set "PS_MSI_URL=https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi"
  set "PS_MSI=%TEMP%\powershell-latest.msi"
  curl.exe -L -o "%PS_MSI%" "%PS_MSI_URL%" >>"%LOG_FILE%" 2>&1
  if errorlevel 1 goto :no_ps
  msiexec.exe /i "%PS_MSI%" /qn /norestart >>"%LOG_FILE%" 2>&1
  where powershell.exe >nul 2>&1
  if errorlevel 1 goto :no_ps
  echo [INFO] Installed PowerShell from %PS_MSI_URL%>>"%LOG_FILE%"
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_checker.ps1" -LogPath "%LOG_DIR%" -LogFile "%LOG_FILE%" %*
endlocal
exit /b %errorlevel%

:no_ps
echo [ERROR] PowerShell is still missing. Please install it from: https://aka.ms/powershell-release?tag=stable>>"%LOG_FILE%"
echo PowerShell is still missing. Install it from: https://aka.ms/powershell-release?tag=stable
pause
endlocal
exit /b 1
