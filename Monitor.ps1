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

    # Швидкий об'єкт для Ping
    $pingSender = New-Object System.Net.NetworkInformation.Ping
    
    # 1. Ping (10 запитів, швидкий таймаут 1000мс = 1сек)
    $failedPings = 0
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $reply = $pingSender.Send($config.TargetPingIP, 1000)
            if ($reply.Status -ne [System.Net.NetworkInformation.IPStatus]::Success) {
                $failedPings++
            }
        } catch {
            $failedPings++
        }
    }
    
    if ($failedPings -gt 5) {
        $pingOk = $false
        $pingLogText = "Втрат: $failedPings/10"
    } else {
        $pingOk = $true
        $pingLogText = "ОК"
    }

    # 2. Ping доменного імені та перевірка DNS
    $failedDns = 0
    $dnsResolved = $false
    try {
        if (Resolve-DnsName -Name $config.TestDomain -ErrorAction SilentlyContinue) {
            $dnsResolved = $true
        }
    } catch { }

    if ($dnsResolved) {
        # Якщо резолвиться, пінгуємо домен (10 разів, швидкий пін)
        for ($j = 0; $j -lt 10; $j++) {
            try {
                $replyDns = $pingSender.Send($config.TestDomain, 1000)
                if ($replyDns.Status -ne [System.Net.NetworkInformation.IPStatus]::Success) {
                    $failedDns++
                }
            } catch {
                $failedDns++
            }
        }
        if ($failedDns -gt 5) {
            $dnsOk = $false
            $dnsLogText = "Втрат по домену: $failedDns/10"
        } else {
            $dnsOk = $true
            $dnsLogText = "ОК"
        }
    } else {
        $dnsOk = $false
        $dnsLogText = "Помилка DNS: Не резолвиться"
    }

    # 3. MAC
    $currentMac = "00:00:00:00:00:00"
    if (![string]::IsNullOrEmpty($config.ExpectedGatewayMAC)) {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
        if ($gateway) {
            $neighbor = Get-NetNeighbor -IPAddress $gateway -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($neighbor.LinkLayerAddress) {
                $currentMac = $neighbor.LinkLayerAddress -replace '-', ':'
            }
        }
        
        $expectedMac = $config.ExpectedGatewayMAC -replace '-', ':'
        if ($currentMac.ToUpper() -ne $expectedMac.ToUpper()) {
            $macOk = $false
        }
    }

    # Condition: вилогінюємо, якщо ДНС/домен не працює, АБО IP не пінгується, АБО MAC неправильний
    $conditionFailed = (-not $dnsOk) -or (-not $pingOk) -or (-not $macOk)

    if ($conditionFailed) {
        if ($lastStatusOk) {
            Write-Log "УВАГА! Проблема з мережею або MAC. (IP Ping: $pingLogText, DNS/Domain: $dnsLogText, MAC: $currentMac). Початок відліку..."
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
