# build_crosscheck.ps1 — Mission 10 overlay (user-approved 2026-06-28).
# Fetches the daily UNOFFICIAL Yahoo Finance cross-check for registry rows carrying a
# `crosscheck` spec, converts to the spine unit via the registry multiplier, and writes a
# SEPARATE store (cleaned_data/crosscheck_latest.csv) — never the spine history. By rule
# Yahoo is corroboration, not a spine: these values are labelled unofficial and are NOT
# captured/charted observations. PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 } catch {}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')

$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 commodity-dashboard-crosscheck/1.0'
$outPath = Join-Path $base 'cleaned_data\crosscheck_latest.csv'
$reg = @(Import-Csv (Get-NewestRegistry (Join-Path $base 'registry')).FullName)
$ccRows = @($reg | Where-Object { ([string]$_.crosscheck).Trim() -ne '' })

# spine latest value per row (from captured history)
$histPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$spineLatest = @{}
if (Test-Path $histPath) {
  foreach ($g in (Import-Csv $histPath | Group-Object row_id)) {
    $last = @($g.Group | Sort-Object date)[-1]
    $spineLatest[$g.Name] = [double]$last.value
  }
}

function Get-YahooLast {
  param([string]$Ticker)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$Ticker`?interval=1d&range=10d"
  $r = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $UA } -TimeoutSec 30
  $res = $r.chart.result
  if ($null -eq $res) { throw ('yahoo error: ' + [string]$r.chart.error.code) }
  $ts = @($res[0].timestamp); $cl = @($res[0].indicators.quote[0].close)
  for ($i = $cl.Count - 1; $i -ge 0; $i--) {
    if ($null -ne $cl[$i]) { return @{ date = ([datetimeoffset]::FromUnixTimeSeconds([long]$ts[$i])).ToString('yyyy-MM-dd'); value = [double]$cl[$i] } }
  }
  throw 'no non-null close'
}

$results = New-Object System.Collections.Generic.List[object]
$lastFetch = $null
foreach ($r in $ccRows) {
  $parts = ([string]$r.crosscheck) -split '#'   # source#ticker#mult#native_unit
  $src = $parts[0]; $ticker = $parts[1]; $mult = [double]$parts[2]; $nativeUnit = $parts[3]
  $status = 'ok'; $native = $null; $date = ''; $vSpine = $null; $ratio = $null
  try {
    if ($null -ne $lastFetch) { $el = ((Get-Date) - $lastFetch).TotalSeconds; if ($el -lt 3) { Start-Sleep -Seconds ([math]::Ceiling(3 - $el)) } }
    $a = Get-YahooLast -Ticker $ticker; $lastFetch = Get-Date
    Start-Sleep -Seconds 3
    $b = Get-YahooLast -Ticker $ticker; $lastFetch = Get-Date
    if ($a.value -ne $b.value -or $a.date -ne $b.date) { $status = 'unstable-intrasession' }   # honest note; take later read
    $native = [double]$b.value; $date = [string]$b.date
    $vSpine = [math]::Round($native * $mult, 6)
    if ($spineLatest.ContainsKey($r.row_id) -and [double]$spineLatest[$r.row_id] -ne 0) {
      $ratio = [math]::Round($vSpine / [double]$spineLatest[$r.row_id], 3)
    }
  } catch {
    $status = ('fetch-failed: ' + ($_.Exception.Message -replace '\s+', ' '))
  }
  $results.Add([pscustomobject]@{
    row_id = $r.row_id; source = $src; ticker = $ticker; date = $date
    native_value = $native; native_unit = $nativeUnit; spine_unit = [string]$r.unit
    value_spine_unit = $vSpine; spine_value = $(if ($spineLatest.ContainsKey($r.row_id)) { $spineLatest[$r.row_id] } else { $null })
    ratio_vs_spine = $ratio; status = $status
  })
  Write-Host ("  {0} <- {1} ({2}): {3} {4} -> {5} {6} (spine {7}, ratio {8}) {9}" -f $r.row_id, $ticker, $src, $native, $nativeUnit, $vSpine, $r.unit, $results[$results.Count-1].spine_value, $ratio, $status)
}
$results | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
$okN = @($results | Where-Object { $_.status -eq 'ok' }).Count
Write-Host ("crosscheck_latest.csv: {0}/{1} ok" -f $okN, $results.Count)
exit 0
