$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$passed = 0
$failed = 0

function Write-Result {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Details = ''
    )
    if ($Ok) {
        $script:passed++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    } else {
        $script:failed++
        if ($Details) {
            Write-Host "[FAIL] $Name - $Details" -ForegroundColor Red
        } else {
            Write-Host "[FAIL] $Name" -ForegroundColor Red
        }
    }
}

function Test-PortClosed {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('localhost', $Port, $null, $null)
        $connected = $iar.AsyncWaitHandle.WaitOne(2000, $false)
        if ($connected) {
            $client.EndConnect($iar)
            return $false
        }
        return $true
    } catch {
        return $true
    } finally {
        $client.Close()
    }
}

# 1. Compose services: running, db healthy
$services = @()
try {
    $raw = docker compose ps --format json
    $lines = @($raw | Where-Object { $_ -and $_.Trim() -ne '' })
    $joined = ($lines -join "`n").Trim()
    if ($joined.StartsWith('[')) {
        $services = @($joined | ConvertFrom-Json)
    } elseif ($joined -ne '') {
        $services = @($lines | ForEach-Object { $_ | ConvertFrom-Json })
    }

    $required = @('db', 'backend', 'frontend')
    $errors = @()
    foreach ($name in $required) {
        $svc = $services | Where-Object { $_.Service -eq $name } | Select-Object -First 1
        if ($null -eq $svc) {
            $errors += "$name missing"
            continue
        }
        if ($svc.State -ne 'running') {
            $errors += "$name state=$($svc.State)"
        }
        if ($name -eq 'db' -and $svc.Health -ne 'healthy') {
            $errors += "db health=$($svc.Health)"
        }
    }

    $ok = ($errors.Count -eq 0)
    Write-Result -Name 'Compose services running, db healthy' -Ok $ok -Details ($errors -join '; ')
} catch {
    Write-Result -Name 'Compose services running, db healthy' -Ok $false -Details $_.Exception.Message
}

# 2. Frontend
try {
    $resp = Invoke-WebRequest -Uri 'http://localhost:8080' -UseBasicParsing
    Write-Result -Name 'GET http://localhost:8080 returns 200' -Ok ($resp.StatusCode -eq 200) -Details "StatusCode=$($resp.StatusCode)"
} catch {
    Write-Result -Name 'GET http://localhost:8080 returns 200' -Ok $false -Details $_.Exception.Message
}

# 3. Backend through Nginx
try {
    $resp = Invoke-WebRequest -Uri 'http://localhost:8080/api/' -UseBasicParsing
    Write-Result -Name 'GET http://localhost:8080/api/ returns 200' -Ok ($resp.StatusCode -eq 200) -Details "StatusCode=$($resp.StatusCode)"
} catch {
    Write-Result -Name 'GET http://localhost:8080/api/ returns 200' -Ok $false -Details $_.Exception.Message
}

# 4. db and backend are not reachable from the host
foreach ($port in @(5432, 8000)) {
    $closed = Test-PortClosed -Port $port
    Write-Result -Name "Port $port is closed on localhost" -Ok $closed -Details "Port $port is open"
}

# 5. Only port 8080 is published
try {
    $publishedPorts = @()
    foreach ($svc in $services) {
        if ($null -ne $svc.Publishers) {
            foreach ($pub in $svc.Publishers) {
                if ($pub.PublishedPort -and [int]$pub.PublishedPort -gt 0) {
                    $publishedPorts += [int]$pub.PublishedPort
                }
            }
        }
    }
    $uniquePorts = @($publishedPorts | Sort-Object -Unique)
    $only8080 = ($uniquePorts.Count -eq 1 -and $uniquePorts[0] -eq 8080)
    Write-Result -Name 'Only port 8080 is published' -Ok $only8080 -Details ("Published ports: " + ($uniquePorts -join ', '))
} catch {
    Write-Result -Name 'Only port 8080 is published' -Ok $false -Details $_.Exception.Message
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "SUMMARY: $passed passed, $failed failed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SUMMARY: $passed passed, $failed failed" -ForegroundColor Red
    exit 1
}
