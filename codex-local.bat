@echo off
setlocal EnableExtensions

set "REPO_MAIN=%~dp0main"
set "PWSH=C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.3.0_x64__8wekyb3d8bbwe\pwsh.exe"

if not exist "%PWSH%" set "PWSH=pwsh.exe"

"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '%REPO_MAIN%'; Write-Host 'Starting Codex in:' (Get-Location); codex -c 'mcp_servers={}'"

if errorlevel 1 (
  echo.
  echo codex-local failed. Error code: %errorlevel%
)

echo.
pause
