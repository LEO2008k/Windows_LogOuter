$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptPath "config.json"
$alertFormScript = Join-Path $scriptPath "ShowAlert.ps1"
$logFile = Join-Path $scriptPath "LockerMonitor.log"

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$stamp] $Message"
}

Write-Log "Служба моніторингу запущена для поточного користувача."

$failureTimeSeconds = 0
$lastStatusOk = $true # Щоб не спамити в логах каждую перевірку

while ($true) {
    if (-not (Test-Path $configFile)) {
        Start-Sleep -Seconds 10
        continue
    }

    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
    } catch {
        Write-Log "ПОМИЛКА: Неможливо прочитати config.json."
        Start-Sleep -Seconds 10
        continue
    }
    
    $interval = $config.CheckIntervalSeconds
    if ($interval -le 0) { $interval = 30 }

    $pingOk = $false
    $dnsOk = $false
    $macOk = $true
    $currentMac = ""

    # 1. Ping
    if (Test-Connection -ComputerName $config.TargetPingIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        $pingOk = $true
    }

    # 2. DNS
    try {
        if (Resolve-DnsName -Name $config.TestDomain -ErrorAction SilentlyContinue) {
            $dnsOk = $true
        }
    } catch { }

    # 3. MAC
    if (![string]::IsNullOrEmpty($config.ExpectedGatewayMAC)) {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
        if ($gateway) {
            $neighbor = Get-NetNeighbor -IPAddress $gateway -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($neighbor.LinkLayerAddress) {
                $currentMac = $neighbor.LinkLayerAddress -replace '-', ':'
                $expectedMac = $config.ExpectedGatewayMAC -replace '-', ':'
                if ($currentMac.ToUpper() -ne $expectedMac.ToUpper()) {
                    $macOk = $false
                }
            }
        }
    }

    # Condition
    $conditionFailed = (-not $pingOk -and -not $dnsOk) -or (-not $macOk)

    if ($conditionFailed) {
        if ($lastStatusOk) {
            Write-Log "УВАГА! Зникло з'єднання або змінено MAC-адресу. (Ping: $pingOk, DNS: $dnsOk, MAC: $currentMac). Початок відліку..."
        }
        $lastStatusOk = $false
        
        $failureTimeSeconds += $interval
        if ($failureTimeSeconds -ge $config.TriggerDelaySeconds) {
            $alertRunning = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" | Where-Object { $_.CommandLine -match "ShowAlert.ps1" }
            
            if (-not $alertRunning) {
                Write-Log "ЧАС ВИЙШОВ ($failureTimeSeconds сек). Запуск спливаючого вікна ShowAlert.ps1..."
                Start-Process "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$alertFormScript`""
            }
            # Скидаємо лічильник
            $failureTimeSeconds = 0
        }
    } else {
        if (-not $lastStatusOk) {
             Write-Log "З'єднання відновлено або MAC-адреса правильна. Зроблено відкат лічильника."
        }
        $lastStatusOk = $true
        $failureTimeSeconds = 0
    }

    Start-Sleep -Seconds $interval
}
