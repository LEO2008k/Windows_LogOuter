@echo off
NET SESSION >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting Administrative privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    exit /b
)

pushd "%~dp0"

echo =======================================================
echo          Installing Windows Locker Monitor
echo =======================================================
echo.
echo Running PowerShell install script...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "InstallTask.ps1"

echo.
echo =======================================================
echo Installation complete. You can close this window.
echo =======================================================
timeout /t 5 >nul
