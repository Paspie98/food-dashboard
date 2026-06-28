# test_registry_integrity.ps1 — Mission 1 fatal gate.
# Validates the newest commodity_registry_v*_active.csv against docs/registry_spec.md.
# Exit 0 = PASS, exit 1 = FAIL. Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$regDir = Join-Path $base 'registry'

# Reader rule: prefer newest version with fallback (spec section 1).
$regFiles = Get-ChildItem -Path $regDir -Filter 'commodity_registry_v*_active.csv' |
  Sort-Object { [int]([regex]::Match($_.Name, 'v(\d+)_active').Groups[1].Value) } -Descending
if (-not $regFiles -or @($regFiles).Count -eq 0) {
  Write-Host 'FAIL: no commodity_registry_v*_active.csv found'; exit 1
}
$regPath = $regFiles[0].FullName
Write-Host ("Registry under test: {0}" -f $regFiles[0].Name)

$rows = @(Import-Csv -Path $regPath)
$failures = New-Object System.Collections.Generic.List[string]
function Fail([string]$msg) { $script:failures.Add($msg) }

# --- Allowed value sets (spec section 3) ---
$validSegments = @('S1','S2','S3','S4','S5')   # v7 re-cut: S1 farm inputs, S2 raw crops, S3 processed ingredients, S4 logistics & energy, S5 packaging
$validClasses  = @('realised','forecast')
$validTiers    = @('1','2','3')
$validFamilies = @('worldbank','imf','fred','eia','eu_oil_bulletin','eu_agrifood','eurostat','usda','icco','ico','fao','mpob','licensed_upload')
$validAccess   = @('open','open-with-key','licensed-upload')
$validCadence  = @('daily','weekly','monthly','quarterly')
$budgetMap     = @{ 'daily'='7d'; 'weekly'='3w'; 'monthly'='3m'; 'quarterly'='2q' }
$validProbe    = @('pending','proven','failed','watchlist','licensed')
$validChart    = @('yes','context-only')
$mandatory     = @('row_id','commodity','segment','series_name','relevance','data_class','tier',
                   'institution','source_family','endpoint','access','refresh_cadence',
                   'staleness_budget','unit','geography','chartable','probe_status')

# Banned-words discipline applies to all generated text incl. registry prose (defensive).
$bannedWords = @('worst since','soar','skyrocket','collapse','crisis','super el nino',
                 'perfect storm','unprecedented','plunge','explode')

# --- Check 1: row count ---
$n = [int]@($rows).Count
if ($n -eq 0) { Fail 'registry has zero rows' }
if ($n -lt 60 -or $n -gt 90) {
  Write-Host ("WARN: row count {0} outside 60-90 target (not fatal; no padding doctrine)" -f $n)
}

# --- Check 2: duplicate / malformed row_ids ---
$idGroups = $rows | Group-Object row_id
foreach ($g in $idGroups) {
  if ([int]$g.Count -gt 1) { Fail ("duplicate row_id: {0}" -f $g.Name) }
}
foreach ($r in $rows) {
  if ($r.row_id -notmatch '^[A-Z]{2}-\d{3}$') { Fail ("malformed row_id: '{0}'" -f $r.row_id) }
}

# --- Check 3: mandatory fields populated ---
foreach ($r in $rows) {
  foreach ($f in $mandatory) {
    $v = [string]$r.$f
    if ($null -eq $v -or $v.Trim() -eq '') { Fail ("{0}: mandatory field '{1}' empty" -f $r.row_id, $f) }
  }
}

# --- Check 4: enumerated values ---
foreach ($r in $rows) {
  if ($validSegments -notcontains $r.segment)        { Fail ("{0}: invalid segment '{1}'" -f $r.row_id, $r.segment) }
  if ($validClasses -notcontains $r.data_class)      { Fail ("{0}: invalid data_class '{1}'" -f $r.row_id, $r.data_class) }
  if ($validTiers -notcontains ([string]$r.tier).Trim()) { Fail ("{0}: invalid tier '{1}'" -f $r.row_id, $r.tier) }
  if ($validFamilies -notcontains $r.source_family)  { Fail ("{0}: source_family '{1}' not in allowed list (ask-first rule)" -f $r.row_id, $r.source_family) }
  if ($validAccess -notcontains $r.access)           { Fail ("{0}: invalid access '{1}'" -f $r.row_id, $r.access) }
  if ($validCadence -notcontains $r.refresh_cadence) { Fail ("{0}: invalid refresh_cadence '{1}'" -f $r.row_id, $r.refresh_cadence) }
  if ($validProbe -notcontains $r.probe_status)      { Fail ("{0}: invalid probe_status '{1}'" -f $r.row_id, $r.probe_status) }
  if ($validChart -notcontains $r.chartable)         { Fail ("{0}: invalid chartable '{1}'" -f $r.row_id, $r.chartable) }
}

# --- Check 5: every segment represented ---
foreach ($l in $validSegments) {
  $c = [int]@($rows | Where-Object { $_.segment -eq $l }).Count
  if ($c -eq 0) { Fail ("segment not represented: {0}" -f $l) }
}

# --- Check 6: tier-3 rows must be non-chartable ---
foreach ($r in $rows) {
  if (([int]$r.tier) -eq 3 -and $r.chartable -ne 'context-only') {
    Fail ("{0}: tier-3 row must be chartable=context-only" -f $r.row_id)
  }
}

# --- Check 7: licensed-upload lane invariants ---
foreach ($r in $rows) {
  $isLic = ($r.access -eq 'licensed-upload')
  $epLic = ($r.endpoint -eq 'uploads_inbox')
  if ($isLic -ne $epLic) { Fail ("{0}: access=licensed-upload must pair with endpoint=uploads_inbox (and only then)" -f $r.row_id) }
  if ($isLic) {
    if ($r.inbox_pattern -notmatch '^bloomberg_weekly_\*\.xlsx#settlements#.+$') {
      Fail ("{0}: licensed-upload row lacks valid inbox_pattern" -f $r.row_id)
    }
    if ($r.probe_status -ne 'licensed') { Fail ("{0}: licensed-upload row must have probe_status=licensed" -f $r.row_id) }
    if ($r.source_family -ne 'licensed_upload') { Fail ("{0}: licensed-upload row must have source_family=licensed_upload" -f $r.row_id) }
  } else {
    if (([string]$r.inbox_pattern).Trim() -ne '') { Fail ("{0}: non-licensed row carries inbox_pattern" -f $r.row_id) }
    if ($r.endpoint -notmatch '^https?://') { Fail ("{0}: open row endpoint is not a retrievable URL" -f $r.row_id) }
    if ($r.probe_status -eq 'licensed') { Fail ("{0}: open row cannot have probe_status=licensed" -f $r.row_id) }
  }
}

# --- Check 8: staleness budget matches cadence map (inherited day one) ---
foreach ($r in $rows) {
  $want = [string]$budgetMap[$r.refresh_cadence]
  if ($want -ne '' -and $r.staleness_budget -ne $want) {
    Fail ("{0}: staleness_budget '{1}' does not match cadence map ({2} -> {3})" -f $r.row_id, $r.staleness_budget, $r.refresh_cadence, $want)
  }
}

# --- Check 9: key placeholders, never raw keys ---
foreach ($r in $rows) {
  if ($r.access -eq 'open-with-key' -and $r.source_family -eq 'fred' -and $r.endpoint -notmatch '\{KEY\}') {
    Fail ("{0}: FRED open-with-key endpoint must embed {{KEY}} placeholder" -f $r.row_id)
  }
  if ($r.access -eq 'open-with-key' -and $r.source_family -eq 'eia' -and $r.endpoint -notmatch '\{KEY\}') {
    Fail ("{0}: EIA open-with-key endpoint must embed {{KEY}} placeholder" -f $r.row_id)
  }
  if ($r.endpoint -match 'api_key=(?!\{KEY\})[A-Za-z0-9]{16,}') {
    Fail ("{0}: endpoint appears to embed a raw API key" -f $r.row_id)
  }
}

# --- Check 10: banned-words scan over registry prose ---
foreach ($r in $rows) {
  $prose = (([string]$r.series_name) + ' ' + ([string]$r.relevance) + ' ' + ([string]$r.notes)).ToLowerInvariant()
  foreach ($w in $bannedWords) {
    if ($prose.Contains($w)) { Fail ("{0}: banned word '{1}' in registry prose" -f $r.row_id, $w) }
  }
}

# --- Check 11: crosscheck field (optional; overlay only, never a spine) ---
foreach ($r in $rows) {
  $cc = [string]$r.crosscheck
  if ($cc.Trim() -eq '') { continue }
  if ($cc -notmatch '^yahoo#[^#]+#[0-9]+(\.[0-9]+)?#.+$') { Fail ("{0}: malformed crosscheck '{1}' (want yahoo#ticker#mult#native_unit)" -f $r.row_id, $cc) }
  if ($r.chartable -ne 'yes' -or $r.data_class -ne 'realised') { Fail ("{0}: crosscheck only allowed on chartable realised rows" -f $r.row_id) }
}

# --- Summary counts (consumed by qa/m1_registry_QA.md) ---
Write-Host ''
Write-Host ("rows_total={0}" -f $n)
foreach ($l in $validSegments) {
  Write-Host ("segment {0} = {1}" -f $l, [int]@($rows | Where-Object { $_.segment -eq $l }).Count)
}
foreach ($t in $validTiers) {
  Write-Host ("tier {0} = {1}" -f $t, [int]@($rows | Where-Object { ([string]$_.tier).Trim() -eq $t }).Count)
}
$famGroups = $rows | Group-Object source_family | Sort-Object Name
foreach ($g in $famGroups) { Write-Host ("family {0} = {1}" -f $g.Name, [int]$g.Count) }
Write-Host ("data_class realised = {0}; forecast = {1}" -f `
  [int]@($rows | Where-Object { $_.data_class -eq 'realised' }).Count, `
  [int]@($rows | Where-Object { $_.data_class -eq 'forecast' }).Count)
Write-Host ("access open = {0}; open-with-key = {1}; licensed-upload = {2}" -f `
  [int]@($rows | Where-Object { $_.access -eq 'open' }).Count, `
  [int]@($rows | Where-Object { $_.access -eq 'open-with-key' }).Count, `
  [int]@($rows | Where-Object { $_.access -eq 'licensed-upload' }).Count)

Write-Host ''
if ([int]$failures.Count -gt 0) {
  Write-Host ("RESULT: FAIL ({0} violations)" -f [int]$failures.Count)
  foreach ($f in $failures) { Write-Host (" - {0}" -f $f) }
  exit 1
}
Write-Host 'RESULT: PASS (registry integrity)'
exit 0
