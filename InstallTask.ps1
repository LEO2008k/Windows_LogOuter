$taskName = "WindowsLockerAndCheckerMonitor"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Помилка: Цей скрипт потрібно запускати від імені Адміністратора!"
    Write-Host "Натисніть будь-яку клавішу для виходу..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

$scriptPath = Join-Path $PSScriptRoot "Monitor.ps1"
$configFile = Join-Path $PSScriptRoot "config.json"

$targetUser = "BUILTIN\Users"

if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($config.TargetUsername)) {
            $targetUser = $config.TargetUsername
        }
    } catch {}
}

Write-Host "Видалення старого завдання (якщо існує)..."
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Action will launch hidden powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# Trigger at Logon
if ($targetUser -eq "BUILTIN\Users") {
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -GroupId $targetUser -RunLevel Highest
    Write-Host "Створення завдання для ВСІХ користувачів..."
} else {
    # If a specific user is provided
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $targetUser
    $principal = New-ScheduledTaskPrincipal -UserId $targetUser -LogonType Interactive -RunLevel Highest
    Write-Host "Створення завдання для користувача: $targetUser ..."
}

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -Hidden

Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -TaskName $taskName -Description "Моніторинг Інтернету і MAC адреси" -Force

Write-Host "Завдання успішно додано до Планувальника завдань Windows!"
Write-Host "Моніторинг автоматично запуститься при наступному вході в систему для $targetUser."
Write-Host ""
Write-Host "Натисніть будь-яку клавішу для виходу..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
