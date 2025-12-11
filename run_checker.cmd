@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%USERPROFILE%\Logs\MatlabRequirementChecker"

rem Ensure the per-user log folder exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem Pick the next numeric log file (log-001.txt, log-002.txt, ...)
set "LOG_PREFIX=log-"
set "LOG_EXT=.txt"
set "LOG_INDEX=1"
for /f "tokens=*" %%f in ('dir /b /a-d "%LOG_DIR%\%LOG_PREFIX%*%LOG_EXT%" ^| sort') do (
  set "NAME=%%~nf"
  set "NUM=!NAME:%LOG_PREFIX%=!"
  for /f "delims=" %%n in ("!NUM!") do 2>nul set /a "LOG_INDEX=%%n+1"
)
set "PAD=00!LOG_INDEX!"
set "PAD=!PAD:~-3!"
set "LOG_FILE=%LOG_DIR%\%LOG_PREFIX%!PAD!%LOG_EXT%"

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
