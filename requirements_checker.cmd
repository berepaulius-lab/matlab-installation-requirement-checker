@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoLogo -ExecutionPolicy Bypass -File "%SCRIPT_DIR%requirements_checker.ps1" %*
endlocal
