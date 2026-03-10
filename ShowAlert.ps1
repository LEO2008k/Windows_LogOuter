Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptPath "config.json"
$logFile = Join-Path $scriptPath "LockerMonitor.log"

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$stamp] [АЛЕРТ] $Message"
}

if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
    } catch { exit }
} else {
    exit
}

$targetLogoffTimeFile = Join-Path $env:TEMP "WindowsLockerEndTimer.txt"

if (Test-Path $targetLogoffTimeFile) {
    try {
        $expectedLogoffStr = Get-Content $targetLogoffTimeFile
        $script:logoffTime = [DateTime]::Parse($expectedLogoffStr)
        $duration = $script:logoffTime - (Get-Date)
        $script:timeLeft = [math]::Max(0, [int]$duration.TotalSeconds)
    } catch {
        $script:timeLeft = $config.PopupTimerSeconds
        if ($script:timeLeft -le 0) { $script:timeLeft = 120 }
        $script:logoffTime = (Get-Date).AddSeconds($script:timeLeft)
    }
} else {
    $script:timeLeft = $config.PopupTimerSeconds
    if ($script:timeLeft -le 0) { $script:timeLeft = 120 }
    $script:logoffTime = (Get-Date).AddSeconds($script:timeLeft)
    Set-Content -Path $targetLogoffTimeFile -Value $script:logoffTime.ToString("o")
}

Write-Log "Вікно попередження відкрито. Таймер: $script:timeLeft сек."

$form = New-Object System.Windows.Forms.Form
$form.Text = "СИРЕНА - ВТРАТА ІНТЕРНЕТУ"
$form.Size = New-Object System.Drawing.Size(500, 300)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.ControlBox = $false
$form.BackColor = [System.Drawing.Color]::DarkRed

$script:allowClose = $false

# Забороняємо закриття через Alt+F4
$form.Add_FormClosing({
    if (-not $script:allowClose) {
        $_.Cancel = $true
        Write-Log "Спроба махлювання: користувач намагався закрити вікно (Alt+F4/TaskBar). Відмовлено."
    }
})

$lblWarn = New-Object System.Windows.Forms.Label
$lblWarn.Text = "Увага! Відсутнє підключення до Інтернету або виявлено підміну роутера. Ви будете розлогінені автоматично."
$lblWarn.ForeColor = [System.Drawing.Color]::White
$lblWarn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblWarn.Location = New-Object System.Drawing.Point(20, 20)
$lblWarn.Size = New-Object System.Drawing.Size(440, 60)
$lblWarn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblWarn)

$lblTimer = New-Object System.Windows.Forms.Label
$lblTimer.Text = "Залишилось: $script:timeLeft с"
$lblTimer.ForeColor = [System.Drawing.Color]::Yellow
$lblTimer.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$lblTimer.Location = New-Object System.Drawing.Point(20, 100)
$lblTimer.Size = New-Object System.Drawing.Size(440, 60)
$lblTimer.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblTimer)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "ВИЙТИ ЗАРАЗ"
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$btnCancel.Location = New-Object System.Drawing.Point(150, 180)
$btnCancel.Size = New-Object System.Drawing.Size(200, 60)
$btnCancel.BackColor = [System.Drawing.Color]::White
$btnCancel.Add_Click({ 
    Write-Log "Користувач натиснув 'ВИЙТИ ЗАРАЗ'. Примусове виконання logoff..."
    (Get-WmiObject Win32_OperatingSystem).Win32Shutdown(4)
    $script:allowClose = $true
    $form.Close() 
})
$form.Controls.Add($btnCancel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $duration = $script:logoffTime - (Get-Date)
    $script:timeLeft = [math]::Max(0, [int]$duration.TotalSeconds)
    $lblTimer.Text = "Залишилось: $script:timeLeft с"
    if ($script:timeLeft -le 0) {
        $timer.Stop()
        Write-Log "Час сплинув. Примусове (Forced) виконання logoff..."
        (Get-WmiObject Win32_OperatingSystem).Win32Shutdown(4)
        $script:allowClose = $true
        $form.Close()
    }
})
$timer.Start()

$form.ShowDialog() | Out-Null
