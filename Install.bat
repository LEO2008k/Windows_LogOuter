@echo off
:: Змінюємо кодування на UTF-8 для коректного відображення української мови у консолі
chcp 65001 >nul

:: Перевіряємо, чи маємо права Адміністратора
NET SESSION >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Запит прав Адміністратора для встановлення...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Встановлюємо робочу папку (папку з бат-файлом)
cd /d "%~dp0"

echo =======================================================
echo          Встановлення Windows Locker Monitor
echo =======================================================
echo.
echo Запуск інсталяційного скрипта PowerShell...
echo.

:: Запускаємо PowerShell скрипт без обмежень політики безпеки
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "InstallTask.ps1"

echo.
echo =======================================================
echo Встановлення завершене. Тепер це вікно закриється.
echo =======================================================
timeout /t 5 >nul
