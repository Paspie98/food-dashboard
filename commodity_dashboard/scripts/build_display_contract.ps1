# build_display_contract.ps1 — Mission 4 (spec: docs/display_contract_spec.md §2-§3).
# Emits dashboard/display_contract.js: complete, non-generic per-row contracts +
# like-for-like groups + fixed geography colours + layer layout. Deterministic JSON.
# PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')

$historyPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$outPath = Join-Path $base 'dashboard\display_contract.js'
if (-not (Test-Path $historyPath)) { throw 'no captured history - run capture_all.ps1 first' }
$regFile = Get-NewestRegistry (Join-Path $base 'registry')
$reg = @(Import-Csv $regFile.FullName)

$hist = @{}
foreach ($h in (Import-Csv $historyPath)) {
  if (-not $hist.ContainsKey($h.row_id)) { $hist[$h.row_id] = New-Object System.Collections.Generic.List[object] }
  $hist[$h.row_id].Add(@{ date = [string]$h.date; value = [double]$h.value })
}

# --- groups (spec §3): potential membership; contracts attach only captured rows ---
# Licensed-upload rows removed from the registry (review decision 2026-06-12: open-source
# doctrine, no Bloomberg lane) are no longer group members. cocoa_complex dropped — only
# the open World Bank cocoa row (CO-001) survives, so there is nothing to compare.
$groups = [ordered]@{
  'coffee_complex'   = @{ basis = 'indexed'; members = @('CF-001', 'CF-002') }
  'wheat_complex'    = @{ basis = 'indexed'; members = @('WH-001', 'WH-002', 'WH-003') }
  'maize_complex'    = @{ basis = 'indexed'; members = @('MZ-001', 'MZ-002') }
  'vegoil_complex'   = @{ basis = 'level';   members = @('VO-001', 'VO-002', 'VO-003', 'VO-004') }
  'sugar_complex'    = @{ basis = 'indexed'; members = @('SG-001', 'SG-002', 'SG-003') }
  'dairy_eu'         = @{ basis = 'level';   members = @('DY-001', 'DY-002') }
  'nitrogen_complex' = @{ basis = 'indexed'; members = @('FE-001', 'FE-008', 'EN-001') }
  'phosphate_complex'= @{ basis = 'indexed'; members = @('FE-002', 'FE-003', 'FE-005', 'FE-010') }
  'potash_complex'   = @{ basis = 'indexed'; members = @('FE-004', 'FE-011') }
  'fao_indices'      = @{ basis = 'level';   members = @('IX-001', 'IX-002', 'IX-003', 'IX-004', 'IX-005') }
  'eu_packaging_ppi' = @{ basis = 'level';   members = @('PK-002', 'PK-004', 'PK-007', 'PK-009') }
  'eggs_regions'     = @{ basis = 'indexed'; members = @('EG-001', 'EG-002') }
  'crude_complex'    = @{ basis = 'indexed'; members = @('EN-003', 'EN-009') }
  'fuel_pumps'       = @{ basis = 'indexed'; members = @('EN-005', 'EN-006', 'EN-007', 'EN-008') }
  'us_freight_rates' = @{ basis = 'indexed'; members = @('FR-002', 'FR-003', 'FR-004') }
}
$rowGroup = @{}
foreach ($g in $groups.Keys) { foreach ($m in $groups[$g].members) { $rowGroup[$m] = $g } }

$colors = [ordered]@{ 'EU' = '#1f5fbf'; 'US' = '#b3413c'; 'world' = '#3f7a4e'; 'origin-specific' = '#8a6d3b' }
$layers = @('S1', 'S2', 'S3', 'S4', 'S5')   # five-segment sections (JSON keys kept as layer_* for mechanical compat)
$layerLabels = [ordered]@{
  'S1' = 'S1 - Farm inputs'
  'S2' = 'S2 - Raw crops'
  'S3' = 'S3 - Processed ingredients'
  'S4' = 'S4 - Logistics & energy'
  'S5' = 'S5 - Packaging'
}

function Get-Decimals([string]$unit, [double]$latest) {
  if (@('USD/kg', 'USD/MMBtu', 'USD per dozen') -contains $unit) { return 2 }
  if (@('index', 'USc/lb', 'EUR/100kg') -contains $unit) { return 1 }
  if ([math]::Abs($latest) -ge 1000) { return 0 }
  return 1
}

function JEsc([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace '\\', '\\\\'; $s = $s -replace '"', '\"'
  $s = $s -replace "`r", '' -replace "`n", ' ' -replace "`t", ' '
  return $s
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('window.DISPLAY_CONTRACT = {"rows":{')
$first = $true
$titlesSeen = @{}
foreach ($r in ($reg | Sort-Object row_id)) {
  if (-not $hist.ContainsKey($r.row_id)) { continue }
  $obs = @($hist[$r.row_id] | Sort-Object { $_.date })
  $latest = [double]$obs[$obs.Count - 1].value
  $title = [string]$r.series_name
  if ($titlesSeen.ContainsKey($title)) { $title = $title + ' [' + $r.row_id + ']' }
  $titlesSeen[$title] = $true
  $basis = 'level'; if ($r.unit -eq 'index') { $basis = 'index' }
  $winP = ''; $winS = ''
  switch ($r.refresh_cadence) {
    'monthly'   { $winP = '3m';  $winS = '12m' }
    'weekly'    { $winP = '13w'; $winS = '52w' }
    'quarterly' { $winP = '4q';  $winS = '8q' }
    'daily'     { $winP = '30d'; $winS = '365d' }
  }
  $cmp = 'no'
  if ($rowGroup.ContainsKey($r.row_id) -and $r.data_class -eq 'realised') { $cmp = 'yes:' + $rowGroup[$r.row_id] }
  if (-not $first) { [void]$sb.Append(',') }
  $first = $false
  [void]$sb.Append('"' + $r.row_id + '":{')
  [void]$sb.Append('"title":"' + (JEsc $title) + '",')
  [void]$sb.Append('"unit_label":"' + (JEsc $r.unit) + '",')
  [void]$sb.Append('"basis":"' + $basis + '",')
  [void]$sb.Append('"decimals":' + (Get-Decimals $r.unit $latest) + ',')
  [void]$sb.Append('"window_primary":"' + $winP + '",')
  [void]$sb.Append('"window_secondary":"' + $winS + '",')
  [void]$sb.Append('"layer_block":"' + (JEsc $r.segment) + '",')
  [void]$sb.Append('"class_block":"' + (JEsc $r.data_class) + '",')
  [void]$sb.Append('"comparable":"' + $cmp + '",')
  [void]$sb.Append('"geography":"' + (JEsc $r.geography) + '",')
  [void]$sb.Append('"color":"' + $colors[[string]$r.geography] + '",')
  [void]$sb.Append('"staleness_budget":"' + (JEsc $r.staleness_budget) + '"')
  [void]$sb.Append('}')
}
[void]$sb.Append('},"groups":{')
$firstG = $true
foreach ($g in $groups.Keys) {
  if (-not $firstG) { [void]$sb.Append(',') }
  $firstG = $false
  $mJson = (@($groups[$g].members | ForEach-Object { '"' + $_ + '"' })) -join ','
  [void]$sb.Append('"' + $g + '":{"basis":"' + $groups[$g].basis + '","members":[' + $mJson + ']}')
}
[void]$sb.Append('},"colors":{')
[void]$sb.Append((@($colors.Keys | ForEach-Object { '"' + $_ + '":"' + $colors[$_] + '"' }) -join ','))
[void]$sb.Append('},"layout":{"layer_order":[')
[void]$sb.Append((@($layers | ForEach-Object { '"' + $_ + '"' }) -join ','))
[void]$sb.Append('],"layer_labels":{')
[void]$sb.Append((@($layerLabels.Keys | ForEach-Object { '"' + $_ + '":"' + (JEsc $layerLabels[$_]) + '"' }) -join ','))
[void]$sb.Append('}}};')

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("display_contract.js written: {0} row contracts, {1} groups" -f $titlesSeen.Count, $groups.Keys.Count)
exit 0
