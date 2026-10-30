@echo off
setlocal
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo PowerShell 5.1 or later is required.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0ASSISTENTE-IA-WINDOWS.ps1" %*
set "exitcode=%errorlevel%"
if not "%exitcode%"=="0" (
  echo.
  echo The launcher could not start. Check your PowerShell execution policy and the message above.
  pause
)
exit /b %exitcode%
