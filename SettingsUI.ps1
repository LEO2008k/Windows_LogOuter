Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptPath "config.json"

# Load Config
if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Помилка при читанні config.json. Файл пошкоджений?", "Помилка", 0, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Файл config.json не знайдено в папці: $scriptPath", "Помилка", 0, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Налаштування Моніторингу Інтернету (Admin)"
$form.Size = New-Object System.Drawing.Size(420, 390)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Font = $font

# Labels & TextBoxes
$labels = @("Цільовий користувач (Логін)", "Ping IP", "Test Domain", "MAC Роутера", "Інтервал перевірки (сек)", "Час до вікна (сек)", "Таймер вилогування (сек)")
$props = @("TargetUsername", "TargetPingIP", "TestDomain", "ExpectedGatewayMAC", "CheckIntervalSeconds", "TriggerDelaySeconds", "PopupTimerSeconds")
$textBoxes = @{}

$y = 20
for ($i = 0; $i -lt $labels.Count; $i++) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labels[$i]
    $lbl.Location = New-Object System.Drawing.Point(20, $y)
    $lbl.AutoSize = $true
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(220, ($y - 2))
    $txt.Size = New-Object System.Drawing.Size(160, 25)
    $txt.Text = $config.($props[$i])
    $form.Controls.Add($txt)
    $textBoxes[$props[$i]] = $txt

    $y += 35
}

# Button GET MAC
$btnMac = New-Object System.Windows.Forms.Button
$btnMac.Text = "Отримати поточний MAC роутера"
$btnMac.Location = New-Object System.Drawing.Point(20, $y)
$btnMac.Size = New-Object System.Drawing.Size(360, 30)
$btnMac.Add_Click({
    try {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop
        if ($gateway) {
            Test-Connection -ComputerName $gateway -Count 1 -Quiet > $null
            $neighbor = Get-NetNeighbor -IPAddress $gateway -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($neighbor.LinkLayerAddress) {
                # Format MAC: replace hyphens with colons, so it matches Linux formats
                $mac = $neighbor.LinkLayerAddress -replace '-', ':'
                $textBoxes["ExpectedGatewayMAC"].Text = $mac
                [System.Windows.Forms.MessageBox]::Show("MAC $mac успішно отримано!", "Успіх", 0, [System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                [System.Windows.Forms.MessageBox]::Show("Не вдалося знайти MAC-адресу для шлюзу $gateway", "Увага", 0, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Помилка при отриманні MAC", 0, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
$form.Controls.Add($btnMac)

$y += 40

# Save Button
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Зберегти"
$btnSave.Location = New-Object System.Drawing.Point(20, $y)
$btnSave.Size = New-Object System.Drawing.Size(170, 35)
$btnSave.BackColor = [System.Drawing.Color]::LightGreen
$btnSave.Add_Click({
    try {
        $config.TargetUsername = $textBoxes["TargetUsername"].Text.Trim()
        $config.TargetPingIP = $textBoxes["TargetPingIP"].Text
        $config.TestDomain = $textBoxes["TestDomain"].Text
        $config.ExpectedGatewayMAC = $textBoxes["ExpectedGatewayMAC"].Text.Trim()
        $config.CheckIntervalSeconds = [int]$textBoxes["CheckIntervalSeconds"].Text
        $config.TriggerDelaySeconds = [int]$textBoxes["TriggerDelaySeconds"].Text
        $config.PopupTimerSeconds = [int]$textBoxes["PopupTimerSeconds"].Text
        
        $config | ConvertTo-Json -Depth 4 | Out-File $configFile -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Налаштування збережено!", "Успіх", 0, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Помилка збереження", 0, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
$form.Controls.Add($btnSave)

# Cancel Button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Закрити"
$btnCancel.Location = New-Object System.Drawing.Point(210, $y)
$btnCancel.Size = New-Object System.Drawing.Size(170, 35)
$btnCancel.Add_Click({ $form.Close() })
$form.Controls.Add($btnCancel)

$form.ShowDialog() | Out-Null
