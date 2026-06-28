# build_data.ps1 — Mission 4 (spec: docs/display_contract_spec.md §1).
# Consumes captured history ONLY (no fetches) + newest registry metadata.
# Emits dashboard/data.js with deterministic, hand-rolled JSON (stable key order,
# stable number formatting — required for hash-stable artifacts).
# PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')

$historyPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$outPath = Join-Path $base 'dashboard\data.js'
New-Item -ItemType Directory -Force -Path (Join-Path $base 'dashboard') | Out-Null
if (-not (Test-Path $historyPath)) { throw 'no captured history - run capture_all.ps1 first' }

$regFile = Get-NewestRegistry (Join-Path $base 'registry')
$reg = @(Import-Csv $regFile.FullName)
$regVersion = [regex]::Match($regFile.Name, '(v\d+)_active').Groups[1].Value

$hist = @{}
foreach ($h in (Import-Csv $historyPath)) {
  if (-not $hist.ContainsKey($h.row_id)) { $hist[$h.row_id] = New-Object System.Collections.Generic.List[object] }
  $hist[$h.row_id].Add(@{ date = [string]$h.date; value = [double]$h.value })
}

function JEsc([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '"', '\"'
  $s = $s -replace "`r", '' -replace "`n", ' ' -replace "`t", ' '
  return $s
}
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# crosscheck overlay (separate store; NEVER spine history) — attached to meta, not charted
$cc = @{}
$ccPath = Join-Path $base 'cleaned_data\crosscheck_latest.csv'
if (Test-Path $ccPath) { foreach ($x in (Import-Csv $ccPath)) { if ($x.status -eq 'ok') { $cc[$x.row_id] = $x } } }

$selected = [int]@($reg).Count
$capturedIds = @($reg | Where-Object { $hist.ContainsKey($_.row_id) } | ForEach-Object { $_.row_id })
$captured = [int]@($capturedIds).Count
$charted = 0; $latestOnly = 0
foreach ($r in $reg) {
  if (-not $hist.ContainsKey($r.row_id)) { continue }
  $n = [int]$hist[$r.row_id].Count
  if ($n -eq 1) { $latestOnly++ }
  elseif ($n -ge 2 -and $r.chartable -eq 'yes') { $charted++ }
}
$notCaptured = [int]($selected - $captured)

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('window.DASHBOARD_DATA = {')
[void]$sb.Append('"generated_utc":"' + ([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')) + '",')
[void]$sb.Append('"registry_version":"' + $regVersion + '",')
[void]$sb.Append(('"counts":{{"selected":{0},"captured":{1},"charted":{2},"latest_only":{3},"not_captured":{4}}},' -f $selected, $captured, $charted, $latestOnly, $notCaptured))
[void]$sb.Append('"series":{')
$first = $true
foreach ($r in ($reg | Sort-Object row_id)) {
  if (-not $hist.ContainsKey($r.row_id)) { continue }
  if (-not $first) { [void]$sb.Append(',') }
  $first = $false
  [void]$sb.Append('"' + $r.row_id + '":{"meta":{')
  [void]$sb.Append('"row_id":"' + (JEsc $r.row_id) + '",')
  [void]$sb.Append('"commodity":"' + (JEsc $r.commodity) + '",')
  [void]$sb.Append('"segment":"' + (JEsc $r.segment) + '",')
  [void]$sb.Append('"series_name":"' + (JEsc $r.series_name) + '",')
  [void]$sb.Append('"relevance":"' + (JEsc $r.relevance) + '",')
  [void]$sb.Append('"unit":"' + (JEsc $r.unit) + '",')
  [void]$sb.Append('"geography":"' + (JEsc $r.geography) + '",')
  [void]$sb.Append('"institution":"' + (JEsc $r.institution) + '",')
  [void]$sb.Append('"tier":' + ([int]$r.tier) + ',')
  [void]$sb.Append('"data_class":"' + (JEsc $r.data_class) + '",')
  [void]$sb.Append('"access":"' + (JEsc $r.access) + '",')
  [void]$sb.Append('"refresh_cadence":"' + (JEsc $r.refresh_cadence) + '",')
  [void]$sb.Append('"staleness_budget":"' + (JEsc $r.staleness_budget) + '",')
  [void]$sb.Append('"chartable":"' + (JEsc $r.chartable) + '",')
  [void]$sb.Append('"probe_status":"' + (JEsc $r.probe_status) + '"')
  if ($cc.ContainsKey($r.row_id)) {
    $x = $cc[$r.row_id]
    [void]$sb.Append(',"crosscheck":{"source":"' + (JEsc $x.source) + '","ticker":"' + (JEsc $x.ticker) +
      '","value":' + ([double]$x.value_spine_unit).ToString($inv) + ',"unit":"' + (JEsc $x.spine_unit) +
      '","native_value":' + ([double]$x.native_value).ToString($inv) + ',"native_unit":"' + (JEsc $x.native_unit) +
      '","date":"' + (JEsc $x.date) + '","ratio":' + ([double]$x.ratio_vs_spine).ToString($inv) +
      ',"label":"unofficial daily cross-check"}')
  }
  [void]$sb.Append('},"obs":[')
  $obsSorted = @($hist[$r.row_id] | Sort-Object { $_.date })
  for ($i = 0; $i -lt $obsSorted.Count; $i++) {
    if ($i -gt 0) { [void]$sb.Append(',') }
    [void]$sb.Append('["' + $obsSorted[$i].date + '",' + ([double]$obsSorted[$i].value).ToString($inv) + ']')
  }
  [void]$sb.Append(']}')
}
[void]$sb.Append('}};')

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("data.js written: selected={0} captured={1} charted={2} latest_only={3} not_captured={4}" -f $selected, $captured, $charted, $latestOnly, $notCaptured)
Write-Host ("  registry={0}; bytes={1}" -f $regVersion, (Get-Item $outPath).Length)
exit 0
