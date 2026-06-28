# test_crosscheck_integrity.ps1 — Mission 10 overlay gate.
# The Yahoo daily cross-check is a SUPPLEMENT (unofficial, fallback-only by rule). This
# gate is FATAL on correctness violations (a bad spine-unit ratio = a conversion/magnitude
# error; the daily value leaking into the spine history; a missing "unofficial" label) but
# TOLERANT of coverage gaps (Yahoo outage) since the overlay must never break the build.
# Exit 0 PASS / 1 FAIL. PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
. (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'parse_helpers.ps1')
$fails = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]

$reg = @(Import-Csv (Get-NewestRegistry (Join-Path $base 'registry')).FullName)
$specs = @($reg | Where-Object { ([string]$_.crosscheck).Trim() -ne '' })
$ccPath = Join-Path $base 'cleaned_data\crosscheck_latest.csv'
if (-not (Test-Path $ccPath)) {
  if (@($specs).Count -gt 0) { Write-Host ("WARN: {0} crosscheck specs but no crosscheck_latest.csv (overlay not built / source down) - tolerated" -f @($specs).Count) }
  Write-Host 'RESULT: PASS (crosscheck overlay absent, tolerated)'; exit 0
}
$store = @{}; foreach ($x in (Import-Csv $ccPath)) { $store[$x.row_id] = $x }

# spine latest per row (separation check)
$histLatest = @{}
$histPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
if (Test-Path $histPath) { foreach ($g in (Import-Csv $histPath | Group-Object row_id)) { $histLatest[$g.Name] = [double](@($g.Group | Sort-Object date)[-1].value) } }

# data.js meta (label check)
$dRaw = Get-Content (Join-Path $base 'dashboard\data.js') -Raw -Encoding UTF8
$d = $dRaw.Substring($dRaw.IndexOf('{')).TrimEnd().TrimEnd(';') | ConvertFrom-Json

$okN = 0
foreach ($r in $specs) {
  $id = $r.row_id
  $s = $store[$id]
  if ($null -eq $s -or $s.status -ne 'ok') { $warns.Add(("{0}: no live crosscheck (status '{1}')" -f $id, $(if ($s) { $s.status } else { 'absent' }))); continue }
  $okN++
  $ratio = [double]$s.ratio_vs_spine
  if ($ratio -lt 0.33 -or $ratio -gt 3.0) { $fails.Add(("{0}: crosscheck ratio {1} outside [0.33,3.0] - likely a unit-conversion/magnitude error" -f $id, $ratio)) }
  if ([double]$s.value_spine_unit -le 0) { $fails.Add(("{0}: non-positive crosscheck value" -f $id)) }
  # separation: the spine history must NOT contain the daily value — its latest must equal the recorded spine_value
  if ($histLatest.ContainsKey($id) -and [string]$s.spine_value -ne '' -and [math]::Abs([double]$histLatest[$id] - [double]$s.spine_value) -gt 1e-6) {
    $fails.Add(("{0}: spine history latest {1} != recorded spine_value {2} (daily value may have polluted history)" -f $id, $histLatest[$id], $s.spine_value))
  }
  # data.js must carry the crosscheck, labelled unofficial, and the row must still be its own spine
  $meta = $d.series.$id.meta
  if ($null -eq $meta.crosscheck) { $fails.Add(("{0}: data.js meta lacks crosscheck" -f $id)) }
  elseif (([string]$meta.crosscheck.label) -notmatch 'unofficial') { $fails.Add(("{0}: crosscheck not labelled 'unofficial'" -f $id)) }
}

Write-Host ("crosscheck specs: {0}; live-ok: {1}; ratio bounds [0.33,3.0]" -f @($specs).Count, $okN)
foreach ($w in $warns) { Write-Host (' WARN ' + $w) }
if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (crosscheck overlay: ratios sane, spine history uncontaminated, labelled unofficial)'; exit 0
