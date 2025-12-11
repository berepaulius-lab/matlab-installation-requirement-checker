@echo off
setlocal ENABLEDELAYEDEXPANSION
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

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

>"%LOG_FILE%" echo [INFO] Starting log in: %LOG_FILE%
>>"%LOG_FILE%" echo (Everything printed to the screen will also be copied here.)
echo [INFO] Starting log in: %LOG_FILE%
echo (Everything printed to the screen will also be copied here.)

if exist "%SCRIPT_DIR%checker.exe" (
  echo [INFO] Running bundled checker.exe...
  >>"%LOG_FILE%" echo [INFO] Running bundled checker.exe...
  "%SCRIPT_DIR%checker.exe" --log-path "%LOG_FILE%"
  goto :end
)

where node.exe >nul 2>&1
if not errorlevel 1 (
  echo [INFO] Using Node.js to run checker.js...
  >>"%LOG_FILE%" echo [INFO] Using Node.js to run checker.js...
  node "%SCRIPT_DIR%checker.js" --log-path "%LOG_FILE%"
  goto :end
)

echo [WARN] Neither checker.exe nor Node.js is available. Running minimal batch checks...
>>"%LOG_FILE%" echo [WARN] Neither checker.exe nor Node.js is available. Running minimal batch checks...
call :batch_checks

goto :end

:batch_checks
echo ------------------------------------------------------------>>"%LOG_FILE%"
echo BASIC CHECKS (batch fallback)>>"%LOG_FILE%"
echo ------------------------------------------------------------>>"%LOG_FILE%"
echo BASIC CHECKS (batch fallback)

ver >"%TEMP%\ver.tmp"
for /f "usebackq tokens=*" %%v in ("%TEMP%\ver.tmp") do set "OS_VER=%%v"
del "%TEMP%\ver.tmp" >nul 2>&1
echo [INFO] OS version: %OS_VER%
>>"%LOG_FILE%" echo [INFO] OS version: %OS_VER%

where java.exe >nul 2>&1
if errorlevel 1 (
  echo [WARN] Java: not found
  >>"%LOG_FILE%" echo [WARN] Java: not found
) else (
  for /f "tokens=2*" %%j in ('java -version 2^>^&1 ^| findstr /i "version"') do set "JAVA_VER=%%k"
  if defined JAVA_VER (
    echo [INFO] Java detected: %JAVA_VER%
    >>"%LOG_FILE%" echo [INFO] Java detected: %JAVA_VER%
  ) else (
    echo [INFO] Java detected (version unknown)
    >>"%LOG_FILE%" echo [INFO] Java detected (version unknown)
  )
)

where dotnet.exe >nul 2>&1
if errorlevel 1 (
  echo [WARN] .NET: not found
  >>"%LOG_FILE%" echo [WARN] .NET: not found
) else (
  for /f "tokens=*" %%d in ('dotnet --version 2^>nul') do set "DOTNET_VER=%%d"
  if defined DOTNET_VER (
    echo [INFO] .NET detected: %DOTNET_VER%
    >>"%LOG_FILE%" echo [INFO] .NET detected: %DOTNET_VER%
  ) else (
    echo [INFO] .NET detected (version unknown)
    >>"%LOG_FILE%" echo [INFO] .NET detected (version unknown)
  )
)

set "COMPILER_FOUND=0"
where cl.exe >nul 2>&1 && set "COMPILER_FOUND=1" && echo [INFO] C/C++ compiler: MSVC (cl.exe) && >>"%LOG_FILE%" echo [INFO] C/C++ compiler: MSVC (cl.exe)
where gcc.exe >nul 2>&1 && set "COMPILER_FOUND=1" && echo [INFO] C/C++ compiler: GCC (gcc.exe) && >>"%LOG_FILE%" echo [INFO] C/C++ compiler: GCC (gcc.exe)
where clang.exe >nul 2>&1 && set "COMPILER_FOUND=1" && echo [INFO] C/C++ compiler: Clang (clang.exe) && >>"%LOG_FILE%" echo [INFO] C/C++ compiler: Clang (clang.exe)
if "%COMPILER_FOUND%"=="0" (
  echo [WARN] C/C++ compiler: not found
  >>"%LOG_FILE%" echo [WARN] C/C++ compiler: not found
)

where wmic.exe >nul 2>&1
if not errorlevel 1 (
  for /f "skip=1 tokens=1,3" %%d in ('wmic logicaldisk where "DeviceID='C:'" get DeviceID^,FreeSpace 2^>nul') do if not "%%d"=="" set "DISK_FREE=%%e"
  if defined DISK_FREE (
    echo [INFO] C: free bytes (approx): %DISK_FREE%
    >>"%LOG_FILE%" echo [INFO] C: free bytes (approx): %DISK_FREE%
  )
  for /f "skip=1 tokens=1,2" %%m in ('wmic OS get TotalVisibleMemorySize^,FreePhysicalMemory 2^>nul') do if not "%%m"=="" set "MEM_TOTAL=%%m" & set "MEM_FREE=%%n"
  if defined MEM_TOTAL (
    echo [INFO] Memory (KB): total=%MEM_TOTAL% free=%MEM_FREE%
    >>"%LOG_FILE%" echo [INFO] Memory (KB): total=%MEM_TOTAL% free=%MEM_FREE%
  )
) else (
  echo [INFO] Skipped disk/RAM details (wmic not available)
  >>"%LOG_FILE%" echo [INFO] Skipped disk/RAM details (wmic not available)
)

echo [INFO] Batch fallback finished.
>>"%LOG_FILE%" echo [INFO] Batch fallback finished.
exit /b 0

:end
echo [INFO] Finished. See %LOG_FILE% for details.
>>"%LOG_FILE%" echo [INFO] Finished.
endlocal
