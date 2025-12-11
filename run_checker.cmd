@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%USERPROFILE%\Logs\MatlabRequirementChecker"
set "PREREQ_FAILED=0"

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

call :logmsg "[INFO] Checking Command Prompt prerequisites (curl, msiexec, network) before launching PowerShell..."
call :require_cmd curl.exe "curl.exe is missing. Please enable the built-in curl feature or update Windows 11."
call :require_cmd msiexec.exe "msiexec.exe is missing. Windows Installer must be enabled to continue."

call :logmsg "[INFO] Quick connectivity probe to microsoft.com (downloads need basic internet)..."
ping -n 1 microsoft.com >nul 2>&1
if errorlevel 1 (
  call :logmsg "[WARN] Cannot reach microsoft.com; downloads may fail."
  echo [WARN] Network looks unreachable right now. Downloads may fail.
)

if "%PREREQ_FAILED%"=="1" goto :prereq_fail

where powershell.exe >nul 2>&1
if errorlevel 1 (
  call :logmsg "[WARN] PowerShell not found. Trying to download it automatically..."
  echo PowerShell not found. Trying to download it automatically...
  set "PS_MSI_URL=https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi"
  set "PS_MSI=%TEMP%\powershell-latest.msi"
  curl.exe -L -o "%PS_MSI%" "%PS_MSI_URL%" >>"%LOG_FILE%" 2>&1
  if errorlevel 1 goto :no_ps
  msiexec.exe /i "%PS_MSI%" /qn /norestart >>"%LOG_FILE%" 2>&1
  where powershell.exe >nul 2>&1
  if errorlevel 1 goto :no_ps
  call :logmsg "[INFO] Installed PowerShell from %PS_MSI_URL%"
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_checker.ps1" -LogPath "%LOG_DIR%" -LogFile "%LOG_FILE%" %*
endlocal
exit /b %errorlevel%

:no_ps
call :logmsg "[ERROR] PowerShell is still missing. Install it from: https://aka.ms/powershell-release?tag=stable"
echo PowerShell is still missing. Install it from: https://aka.ms/powershell-release?tag=stable
pause
endlocal
exit /b 1

:prereq_fail
call :logmsg "[ERROR] Missing Command Prompt prerequisites. Fix the items above, then run again."
echo Fix the missing prerequisites above, then run this launcher again.
pause
endlocal
exit /b 1

:require_cmd
where %~1 >nul 2>&1
if errorlevel 1 (
  call :logmsg "[ERROR] %~2"
  echo %~2
  set "PREREQ_FAILED=1"
)
goto :eof

:logmsg
echo %~1>>"%LOG_FILE%"
echo %~1
goto :eof
