# test_display_contract.ps1 — Mission 4 fatal gate (spec §4.2).
# Every captured series has a COMPLETE, non-generic contract; titles unique; group
# references valid; forecast rows never grouped. Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
function Load-WindowJs([string]$path) {
  $raw = Get-Content $path -Raw -Encoding UTF8
  return ($raw.Substring($raw.IndexOf('{')).TrimEnd().TrimEnd(';') | ConvertFrom-Json)
}
$d = Load-WindowJs (Join-Path $base 'dashboard\data.js')
$c = Load-WindowJs (Join-Path $base 'dashboard\display_contract.js')
$fails = New-Object System.Collections.Generic.List[string]
$required = @('title', 'unit_label', 'basis', 'window_primary', 'window_secondary', 'layer_block', 'class_block', 'comparable', 'geography', 'color', 'staleness_budget')

$titles = @{}
foreach ($p in $d.series.PSObject.Properties) {
  $id = $p.Name
  $row = $c.rows.$id
  if ($null -eq $row) { $fails.Add("${id}: captured series has NO display contract"); continue }
  foreach ($f in $required) {
    $v = [string]$row.$f
    if ($null -eq $row.$f -or $v.Trim() -eq '') { $fails.Add("${id}: contract field '$f' empty") }
  }
  if ($null -eq $row.decimals -or [int]$row.decimals -lt 0 -or [int]$row.decimals -gt 4) { $fails.Add("${id}: decimals out of range") }
  if ([string]$row.title -eq $id) { $fails.Add("${id}: generic title (raw row_id)") }
  if ($titles.ContainsKey([string]$row.title)) { $fails.Add("${id}: duplicate title '" + $row.title + "'") }
  $titles[[string]$row.title] = $true
  if ([string]$row.basis -notin @('level', 'index')) { $fails.Add("${id}: invalid basis") }
  $cmp = [string]$row.comparable
  if ($cmp -ne 'no') {
    if ($cmp -notmatch '^yes:([a-z_]+)$') { $fails.Add("${id}: malformed comparable '$cmp'") }
    else {
      $gid = $Matches[1]
      $grp = $c.groups.$gid
      if ($null -eq $grp) { $fails.Add("${id}: comparable references undefined group '$gid'") }
      elseif (@($grp.members) -notcontains $id) { $fails.Add("${id}: not a member of its own group '$gid'") }
    }
    if ([string]$d.series.$id.meta.data_class -eq 'forecast') { $fails.Add("${id}: FORECAST row joined a comparable group (principle 3 violation)") }
  }
  if ([string]$row.class_block -ne [string]$d.series.$id.meta.data_class) { $fails.Add("${id}: class_block diverges from registry data_class") }
}
foreach ($g in $c.groups.PSObject.Properties) {
  if ([string]$g.Value.basis -notin @('level', 'indexed')) { $fails.Add(("group {0}: invalid basis" -f $g.Name)) }
  if (@($g.Value.members).Count -lt 2) { $fails.Add(("group {0}: fewer than 2 potential members" -f $g.Name)) }
}

Write-Host ("contracts checked: {0}; groups: {1}" -f @($d.series.PSObject.Properties).Count, @($c.groups.PSObject.Properties).Count)
if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (display contract integrity)'; exit 0
