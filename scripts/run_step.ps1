param(
    [Parameter(Mandatory = $true)][int]$TotalEps,
    [int]$Generators = 1,
    [int]$Duration = 120,
    [int]$Warmup = 30,
    [int]$Repeat = 1,
    [string]$Url = "http://127.0.0.1:8080",
    [string]$ResultsFile = "results\steps.csv"
)

function Get-TotalLag {
    $output = docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh `
        --bootstrap-server localhost:9092 --describe --group ch-shipper 2>$null
    $total = 0
    foreach ($line in $output) {
        $cols = $line.Trim() -split "\s+"
        if ($cols.Count -gt 5 -and $cols[1] -eq "logs-raw" -and $cols[5] -match '^\d+$') {
            $total += [int64]$cols[5]
        }
    }
    return $total
}

function Wait-Drain([int]$TimeoutSec = 600) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $lag = Get-TotalLag
        if ($lag -eq 0) { return $true }
        Write-Host "  waiting for drain, lag=$lag"
        Start-Sleep -Seconds 5
    }
    Write-Warning "Drain timeout: lag did not reach 0"
    return $false
}

$runId = "s{0}k-r{1}" -f [math]::Round($TotalEps / 1000), $Repeat
$perGenerator = [math]::Round($TotalEps / $Generators)
New-Item -ItemType Directory -Force -Path logs, results | Out-Null

Write-Host "`n=== $runId : $Generators x $perGenerator EPS, $Duration s (warmup $Warmup s) ==="

# 1. Старт с пустой очереди
Wait-Drain | Out-Null

# 2. Генераторы параллельно
$processes = 1..$Generators | ForEach-Object {
    Start-Process -FilePath ".venv\Scripts\python.exe" `
        -ArgumentList "-u generator\generator.py --eps $perGenerator --duration $Duration --url $Url --run-id $runId" `
        -RedirectStandardOutput "logs\$runId-g$_.txt" -NoNewWindow -PassThru
}

# 3. Снимок ресурсов в середине прогона
Start-Sleep -Seconds ([math]::Round($Duration / 2))
docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}" |
    Out-File "logs\$runId-stats.txt"

$processes | Wait-Process

# 4. Очередь в момент окончания нагрузки
$lagEnd = Get-TotalLag
Write-Host "lag at end of load: $lagEnd"

# 5. Итоги генераторов
$totals = Get-Content "logs\$runId-g*.txt" | Select-String "TOTAL"
$sentSum = 0; $lateSum = 0
foreach ($t in $totals) {
    if ($t -match "sent=(\d+)") { $sentSum += [int64]$Matches[1] }
    if ($t -match "late_ticks=(\d+)") { $lateSum += [int64]$Matches[1] }
}

# 6. Дождаться, пока shipper допишет хвост
Wait-Drain | Out-Null
Start-Sleep -Seconds 3

# 7. Метрики на установившемся участке
$sql = @"
WITH
    (SELECT min(collected_at) FROM siem.logs WHERE source = '$runId') AS t0,
    (SELECT max(collected_at) FROM siem.logs WHERE source = '$runId') AS t1,
    t0 + INTERVAL $Warmup SECOND AS w0,
    dateDiff('millisecond', w0, t1) / 1000 AS window_s
SELECT
    count(),
    round(window_s, 1),
    round(countIf(collected_at >= w0) / window_s),
    round(countIf(inserted_at >= w0 AND inserted_at <= t1) / window_s),
    quantileIf(0.5)(dateDiff('millisecond', collected_at, inserted_at), collected_at >= w0),
    quantileIf(0.99)(dateDiff('millisecond', collected_at, inserted_at), collected_at >= w0),
    quantileIf(0.5)(dateDiff('millisecond', ts, collected_at), collected_at >= w0)
FROM siem.logs
WHERE source = '$runId'
"@ -replace "`r?`n", " "

$metrics = docker compose exec clickhouse clickhouse-client --user siem --password siem --format CSV --query $sql

if (-not (Test-Path $ResultsFile)) {
    "run_id,target_eps,generators,sent,late_ticks,lag_end,rows_total,window_s,in_eps,out_eps,pipeline_p50_ms,pipeline_p99_ms,client_p50_ms" |
        Out-File $ResultsFile -Encoding utf8
}
"$runId,$TotalEps,$Generators,$sentSum,$lateSum,$lagEnd,$metrics" | Add-Content $ResultsFile

Write-Host "sent=$sentSum late_ticks=$lateSum"
Write-Host "rows_total,window_s,in_eps,out_eps,p50,p99,client_p50: $metrics"