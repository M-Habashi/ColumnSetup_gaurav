@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PWSH=C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.3.0_x64__8wekyb3d8bbwe\pwsh.exe"

if not exist "%PWSH%" set "PWSH=pwsh.exe"

"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%codex-remote.ps1"

if errorlevel 1 (
  echo.
  echo codex-remote failed. Error code: %errorlevel%
)

echo.
pause
