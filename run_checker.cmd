@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"
set "RUNTIME_DIR=%SCRIPT_DIR%runtime"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"

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

call :log "[INFO] Starting log in: %LOG_FILE%"
call :log "(Everything printed to the screen will also be copied here.)"

if exist "%SCRIPT_DIR%checker.exe" (
  call :log "[INFO] Running bundled checker.exe..."
  "%SCRIPT_DIR%checker.exe" --log-path "%LOG_FILE%"
  goto :end
)

call :ensure_node
if defined NODE_CMD (
  call :log "[INFO] Using Node runtime: %NODE_CMD%"
  "%NODE_CMD%" "%SCRIPT_DIR%checker.js" --log-path "%LOG_FILE%"
  goto :end
)

call :log "[WARN] Could not prepare Node runtime. Running minimal batch checks instead..."
call :batch_checks
goto :end

:log
echo %~1
>>"%LOG_FILE%" echo %~1
goto :eof

:ensure_node
set "NODE_CMD="

rem Prefer an installed Node first
where node.exe >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%N in ('where node.exe') do (
    set "NODE_CMD=%%N"
    goto :eof
  )
)

rem Check for previously downloaded portable Node
call :find_portable_node
if defined NODE_CMD goto :eof

rem Download a portable Node runtime (no admin, no login required)
call :download_node
call :find_portable_node
goto :eof

:find_portable_node
set "NODE_CMD="
for /r "%RUNTIME_DIR%" %%p in (node.exe) do (
  set "NODE_CMD=%%p"
  goto :found_node
)
:found_node
goto :eof

:download_node
set "NODE_VERSION=18.20.3"
set "NODE_ZIP=node-v%NODE_VERSION%-win-x64.zip"
set "NODE_URL=https://nodejs.org/dist/v%NODE_VERSION%/%NODE_ZIP%"
set "NODE_ZIP_PATH=%RUNTIME_DIR%\%NODE_ZIP%"

call :log "[INFO] Downloading portable Node %NODE_VERSION%..."
curl -L "%NODE_URL%" -o "%NODE_ZIP_PATH%" >nul 2>&1
if errorlevel 1 (
  call :log "[WARN] Download failed (curl exit %errorlevel%)."
  goto :eof
)

call :log "[INFO] Extracting portable Node..."
tar -xf "%NODE_ZIP_PATH%" -C "%RUNTIME_DIR%" >nul 2>&1
if errorlevel 1 (
  call :log "[WARN] Extraction failed (tar exit %errorlevel%)."
  goto :eof
)
del "%NODE_ZIP_PATH%" >nul 2>&1
call :log "[INFO] Portable Node unpacked."
goto :eof

:batch_checks
call :log "------------------------------------------------------------"
call :log "BASIC CHECKS (batch fallback)"
call :log "------------------------------------------------------------"

ver >"%TEMP%\ver.tmp"
for /f "usebackq tokens=*" %%v in ("%TEMP%\ver.tmp") do set "OS_VER=%%v"
del "%TEMP%\ver.tmp" >nul 2>&1
call :log "[INFO] OS version: %OS_VER%"

where java.exe >nul 2>&1
if errorlevel 1 (
  call :log "[WARN] Java: not found"
) else (
  for /f "tokens=2*" %%j in ('java -version 2^>^&1 ^| findstr /i "version"') do set "JAVA_VER=%%k"
  if defined JAVA_VER (
    call :log "[INFO] Java detected: %JAVA_VER%"
  ) else (
    call :log "[INFO] Java detected (version unknown)"
  )
)

where dotnet.exe >nul 2>&1
if errorlevel 1 (
  call :log "[WARN] .NET: not found"
) else (
  for /f "tokens=*" %%d in ('dotnet --version 2^>nul') do set "DOTNET_VER=%%d"
  if defined DOTNET_VER (
    call :log "[INFO] .NET detected: %DOTNET_VER%"
  ) else (
    call :log "[INFO] .NET detected (version unknown)"
  )
)

set "COMPILER_FOUND=0"
where cl.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :log "[INFO] C/C++ compiler: MSVC (cl.exe)"
where gcc.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :log "[INFO] C/C++ compiler: GCC (gcc.exe)"
where clang.exe >nul 2>&1 && set "COMPILER_FOUND=1" && call :log "[INFO] C/C++ compiler: Clang (clang.exe)"
if "%COMPILER_FOUND%"=="0" (
  call :log "[WARN] C/C++ compiler: not found"
)

where wmic.exe >nul 2>&1
if not errorlevel 1 (
  for /f "skip=1 tokens=1,3" %%d in ('wmic logicaldisk where "DeviceID='C:'" get DeviceID^,FreeSpace 2^>nul') do if not "%%d"=="" set "DISK_FREE=%%e"
  if defined DISK_FREE (
    call :log "[INFO] C: free bytes (approx): %DISK_FREE%"
  )
  for /f "skip=1 tokens=1,2" %%m in ('wmic OS get TotalVisibleMemorySize^,FreePhysicalMemory 2^>nul') do if not "%%m"=="" set "MEM_TOTAL=%%m" & set "MEM_FREE=%%n"
  if defined MEM_TOTAL (
    call :log "[INFO] Memory (KB): total=%MEM_TOTAL% free=%MEM_FREE%"
  )
) else (
  call :log "[INFO] Skipped disk/RAM details (wmic not available)"
)

call :log "[INFO] Batch fallback finished."
exit /b 0

:end
call :log "[INFO] Finished. See %LOG_FILE% for details."
endlocal
