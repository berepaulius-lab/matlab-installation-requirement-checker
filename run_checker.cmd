@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"
set "PREREQ_FAILED=0"

rem Ensure the local log folder exists beside the launcher
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

call :logmsg "[INFO] Quick connectivity probe (no Microsoft account needed)..."
set "NET_OK=0"
for %%h in (1.1.1.1 example.com cloudflare-dns.com) do (
  ping -n 1 %%h >nul 2>&1 && set "NET_OK=1"
)
if "%NET_OK%"=="1" (
  call :logmsg "[INFO] Basic connectivity looks okay."
) else (
  call :logmsg "[WARN] Network looks unreachable right now. Downloads may fail."
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
  if errorlevel 1 goto :fallback_batch
  msiexec.exe /i "%PS_MSI%" /qn /norestart >>"%LOG_FILE%" 2>&1
  where powershell.exe >nul 2>&1
  if errorlevel 1 goto :fallback_batch
  call :logmsg "[INFO] Installed PowerShell from %PS_MSI_URL%"
)

rem If PowerShell is present, hand off to the rich checker
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_checker.ps1" -LogPath "%LOG_DIR%" -LogFile "%LOG_FILE%" %*
set "EXIT_CODE=%errorlevel%"
endlocal
exit /b %EXIT_CODE%

:fallback_batch
call :logmsg "[WARN] PowerShell is unavailable. Running limited checks directly in Command Prompt..."
echo ------------------------------------------------------------>>"%LOG_FILE%"
echo BASIC CHECKS (batch fallback)>>"%LOG_FILE%"
echo ------------------------------------------------------------>>"%LOG_FILE%"
echo BASIC CHECKS (batch fallback)

rem OS info
ver >"%TEMP%\ver.tmp"
for /f "usebackq tokens=*" %%v in ("%TEMP%\ver.tmp") do set "OS_VER=%%v"
del "%TEMP%\ver.tmp" >nul 2>&1
call :logmsg "[INFO] OS version: %OS_VER%"

rem Java
where java.exe >nul 2>&1
if errorlevel 1 (
  call :logmsg "[WARN] Java: not found"
) else (
  for /f "tokens=2*" %%j in ('java -version 2^>^&1 ^| findstr /i "version"') do set "JAVA_VER=%%k"
  if defined JAVA_VER (
    call :logmsg "[INFO] Java detected: %JAVA_VER%"
  ) else (
    call :logmsg "[INFO] Java detected (version unknown)"
  )
)

rem .NET
where dotnet.exe >nul 2>&1
if errorlevel 1 (
  call :logmsg "[WARN] .NET: not found"
) else (
  for /f "tokens=*" %%d in ('dotnet --version 2^>nul') do set "DOTNET_VER=%%d"
  if defined DOTNET_VER (
    call :logmsg "[INFO] .NET detected: %DOTNET_VER%"
  ) else (
    call :logmsg "[INFO] .NET detected (version unknown)"
  )
)

rem Compilers
set "COMPILER_FOUND=0"
where cl.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :logmsg "[INFO] C/C++ compiler: MSVC (cl.exe)"
where gcc.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :logmsg "[INFO] C/C++ compiler: GCC (gcc.exe)"
where clang.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :logmsg "[INFO] C/C++ compiler: Clang (clang.exe)"
if "%COMPILER_FOUND%"=="0" call :logmsg "[WARN] C/C++ compiler: not found"

rem Disk and memory summaries (best-effort)
where wmic.exe >nul 2>&1
if not errorlevel 1 (
  for /f "skip=1 tokens=1,3" %%d in ('wmic logicaldisk where "DeviceID='C:'" get DeviceID^,FreeSpace 2^>nul') do if not "%%d"=="" set "DISK_FREE=%%e"
  if defined DISK_FREE call :logmsg "[INFO] C: free bytes (approx): %DISK_FREE%"
  for /f "skip=1 tokens=1,2" %%m in ('wmic OS get TotalVisibleMemorySize^,FreePhysicalMemory 2^>nul') do if not "%%m"=="" set "MEM_TOTAL=%%m" & set "MEM_FREE=%%n"
  if defined MEM_TOTAL call :logmsg "[INFO] Memory (KB): total=%MEM_TOTAL% free=%MEM_FREE%"
) else (
  call :logmsg "[INFO] Skipped disk/RAM details (wmic not available)"
)

call :logmsg "[INFO] Batch fallback finished. Install PowerShell for the full UI and auto-fix options."
echo Finished limited checks. Install PowerShell for the full experience.
pause
endlocal
exit /b 0

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
