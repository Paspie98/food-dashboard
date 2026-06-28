# test_axis_sanity.ps1 — Mission 4 fatal gate (spec §4.4).
# No degenerate axes: every charted series has min<max over the full series, and the
# primary comparison window holds >=2 observations. Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
function Load-WindowJs([string]$path) {
  $raw = Get-Content $path -Raw -Encoding UTF8
  return ($raw.Substring($raw.IndexOf('{')).TrimEnd().TrimEnd(';') | ConvertFrom-Json)
}
$d = Load-WindowJs (Join-Path $base 'dashboard\data.js')
$c = Load-WindowJs (Join-Path $base 'dashboard\display_contract.js')
$fails = New-Object System.Collections.Generic.List[string]
$inv = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-ObsDate([string]$s) {
  if ($s -match '^\d{4}-\d{2}$') { return [datetime]::ParseExact($s + '-01', 'yyyy-MM-dd', $inv) }
  return [datetime]::ParseExact($s, 'yyyy-MM-dd', $inv)
}
function Window-Days([string]$w) {
  if ($w -match '^(\d+)([mwqd])$') {
    $n = [int]$Matches[1]
    switch ($Matches[2]) { 'm' { return $n * 31 } 'w' { return $n * 7 } 'q' { return $n * 92 } 'd' { return $n } }
  }
  return 0
}

$checked = 0
foreach ($p in $d.series.PSObject.Properties) {
  $id = $p.Name; $s = $p.Value
  if ([string]$s.meta.chartable -ne 'yes' -or @($s.obs).Count -lt 2) { continue }
  $checked++
  $vals = @($s.obs | ForEach-Object { [double]$_[1] })
  $min = ($vals | Measure-Object -Minimum).Minimum
  $max = ($vals | Measure-Object -Maximum).Maximum
  if ([double]$min -ge [double]$max) { $fails.Add("${id}: degenerate axis (min >= max over full series)") }
  $row = $c.rows.$id
  if ($null -eq $row) { continue }   # display-contract gate owns that failure
  $wDays = Window-Days ([string]$row.window_primary)
  if ($wDays -le 0) { $fails.Add("${id}: unparseable window_primary '" + $row.window_primary + "'"); continue }
  $lastDate = Parse-ObsDate ([string]@($s.obs)[-1][0])
  $cutoff = $lastDate.AddDays(-1.3 * $wDays)
  $inWindow = 0
  foreach ($o in $s.obs) { if ((Parse-ObsDate ([string]$o[0])) -ge $cutoff) { $inWindow++ } }
  if ($inWindow -lt 2) { $fails.Add("${id}: primary window '" + $row.window_primary + "' holds $inWindow obs (<2)") }
}

Write-Host ("charted series checked: {0}" -f $checked)
if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (axis sanity)'; exit 0
