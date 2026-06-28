# test_chart_integrity.ps1 — Mission 4 fatal gate (spec §4.1).
# Every charted series: aligned [date,value] pairs, >=2 obs, finite numbers, strictly
# ascending dates; counts in data.js consistent with payload. Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$dataPath = Join-Path $base 'dashboard\data.js'
if (-not (Test-Path $dataPath)) { Write-Host 'FAIL: dashboard/data.js missing'; exit 1 }
$raw = Get-Content $dataPath -Raw -Encoding UTF8
$json = $raw.Substring($raw.IndexOf('{')).TrimEnd().TrimEnd(';')
$d = $json | ConvertFrom-Json
$fails = New-Object System.Collections.Generic.List[string]

$chartedCalc = 0
foreach ($p in $d.series.PSObject.Properties) {
  $id = $p.Name; $s = $p.Value
  $obs = @($s.obs)
  if (@($obs).Count -ne [int]$s.obs.Count) {}
  if ($s.meta.chartable -eq 'yes' -and @($obs).Count -ge 2) { $chartedCalc++ }
  if (@($obs).Count -lt 2) { $fails.Add("${id}: fewer than 2 observations"); continue }
  $prev = ''
  foreach ($o in $obs) {
    $pair = @($o)
    if (@($pair).Count -ne 2) { $fails.Add("${id}: obs element is not a [date,value] pair"); break }
    $dt = [string]$pair[0]
    $v = $pair[1]
    if ($dt -notmatch '^\d{4}-\d{2}(-\d{2})?$') { $fails.Add("${id}: malformed date '$dt'"); break }
    if ($null -eq $v) { $fails.Add("${id}: null value at $dt"); break }
    $dv = [double]$v
    if ([double]::IsNaN($dv) -or [double]::IsInfinity($dv)) { $fails.Add("${id}: non-finite value at $dt"); break }
    if ($prev -ne '' -and -not ([string]::CompareOrdinal($dt, $prev) -gt 0)) { $fails.Add("${id}: dates not strictly ascending at $dt"); break }
    $prev = $dt
  }
}
if ([int]$d.counts.charted -ne $chartedCalc) { $fails.Add(("counts.charted={0} but payload computes {1}" -f $d.counts.charted, $chartedCalc)) }
if ([int]$d.counts.captured -ne [int]@($d.series.PSObject.Properties).Count) { $fails.Add('counts.captured mismatch vs series payload') }

Write-Host ("series checked: {0}; charted: {1}" -f @($d.series.PSObject.Properties).Count, $chartedCalc)
if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (chart integrity)'; exit 0
