# test_frontend_category_integrity.ps1 — Mission 4 fatal gate (spec §4.3).
# Every contract routes to a defined layer block; every layer has >=1 charted row;
# realised/forecast block routing consistent. Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
function Load-WindowJs([string]$path) {
  $raw = Get-Content $path -Raw -Encoding UTF8
  return ($raw.Substring($raw.IndexOf('{')).TrimEnd().TrimEnd(';') | ConvertFrom-Json)
}
$d = Load-WindowJs (Join-Path $base 'dashboard\data.js')
$c = Load-WindowJs (Join-Path $base 'dashboard\display_contract.js')
$fails = New-Object System.Collections.Generic.List[string]

$layerOrder = @($c.layout.layer_order)
if (@($layerOrder).Count -ne 5) { $fails.Add('layout.layer_order must list exactly the five segments') }
$layerCounts = @{}
foreach ($l in $layerOrder) {
  $layerCounts[[string]$l] = 0
  if ($null -eq $c.layout.layer_labels.$l) { $fails.Add("layer '$l' has no label") }
}
foreach ($p in $c.rows.PSObject.Properties) {
  $id = $p.Name; $row = $p.Value
  $lb = [string]$row.layer_block
  if ($layerOrder -notcontains $lb) { $fails.Add("${id}: layer_block '$lb' not in layout"); continue }
  $meta = $d.series.$id.meta
  if ($null -eq $meta) { $fails.Add("${id}: contract exists but series absent from data.js"); continue }
  if ([string]$meta.segment -ne $lb) { $fails.Add("${id}: layer_block diverges from registry segment") }
  if ([string]$meta.chartable -eq 'yes' -and @($d.series.$id.obs).Count -ge 2 -and [string]$row.class_block -eq 'realised') {
    $layerCounts[$lb] = [int]$layerCounts[$lb] + 1
  }
}
foreach ($l in $layerOrder) {
  if ([int]$layerCounts[[string]$l] -eq 0) { $fails.Add("layer '$l' has zero charted realised rows") }
  else { Write-Host ("  {0}: {1} charted realised rows" -f $l, [int]$layerCounts[[string]$l]) }
}

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (frontend category integrity)'; exit 0
