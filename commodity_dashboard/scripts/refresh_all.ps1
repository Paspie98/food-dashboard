# refresh_all.ps1 — Mission 5 orchestrator.
# validate-registry -> capture -> ingest-licensed -> build-data -> display-contract ->
# synthesis (Mission 7 slot) -> gates -> qa-checks (secrets, numeric-history, ratchet) ->
# freshness -> manifest -> run summary (JSON+MD, consumer schema).
# Fail-closed: BUILD_STATUS is PASS only if every fatal step passed; anything missing
# renders FAILURE downstream (footer derives strictly from the manifest).
# Staleness never fails the build: >budget WARNs (named), >2x budget ESCALATES (named).
# PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')

$startUtc = [datetime]::UtcNow
$startIso = $startUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
$logsDir = Join-Path $base 'logs'
$dashDir = Join-Path $base 'dashboard'
New-Item -ItemType Directory -Force -Path $logsDir, $dashDir | Out-Null

$steps = New-Object System.Collections.Generic.List[object]
function Add-Step([string]$name, [string]$status, [bool]$fatal, [string]$detail) {
  $steps.Add([pscustomobject]@{ step = $name; status = $status; fatal = $fatal; detail = $detail })
  Write-Host ("[{0}] {1} {2}" -f $status, $name, $detail)
}
function Invoke-Step {
  param([string]$Name, [string]$ScriptRel, [bool]$Fatal = $true, [string[]]$ExtraArgs = @())
  $p = Join-Path $base $ScriptRel
  if (-not (Test-Path $p)) {
    if ($Fatal) { Add-Step $Name 'FAILURE' $true 'script missing (fail-closed)' } else { Add-Step $Name 'SKIPPED' $false 'script not present yet' }
    return
  }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $p @ExtraArgs | Out-Host
  $code = $LASTEXITCODE
  if ($code -eq 0) { Add-Step $Name 'PASS' $Fatal '' }
  else {
    if ($Name -eq 'ingest-licensed' -and $code -eq 1) { Add-Step $Name 'WARN' $false 'workbook rejected by lane contract (history untouched)' }
    elseif ($Fatal) { Add-Step $Name 'FAILURE' $true ("exit {0}" -f $code) }
    else { Add-Step $Name 'WARN' $false ("exit {0}" -f $code) }
  }
}

# ---------- 1. pipeline ----------
Invoke-Step 'validate-registry' 'scripts\tests\test_registry_integrity.ps1' $true
$captureStartUtc = [datetime]::UtcNow
Invoke-Step 'capture' 'scripts\capture_all.ps1' $true @('-Quiet')
$captureEndUtc = [datetime]::UtcNow
Invoke-Step 'ingest-licensed' 'scripts\ingest_licensed_uploads.ps1' $false
Invoke-Step 'build-crosscheck' 'scripts\build_crosscheck.ps1' $false   # unofficial daily overlay; non-fatal (source may be down)
$buildStartUtc = [datetime]::UtcNow
Invoke-Step 'build-data' 'scripts\build_data.ps1' $true
Invoke-Step 'build-display-contract' 'scripts\build_display_contract.ps1' $true
Invoke-Step 'synthesis' 'scripts\build_synthesis.ps1' $true    # fatal since Mission 7
$buildEndUtc = [datetime]::UtcNow

# ---------- 2. gates ----------
Invoke-Step 'gate-chart-integrity' 'scripts\tests\test_chart_integrity.ps1' $true
Invoke-Step 'gate-display-contract' 'scripts\tests\test_display_contract.ps1' $true
Invoke-Step 'gate-frontend-category' 'scripts\tests\test_frontend_category_integrity.ps1' $true
Invoke-Step 'gate-axis-sanity' 'scripts\tests\test_axis_sanity.ps1' $true
Invoke-Step 'gate-banned-words' 'scripts\tests\test_banned_words.ps1' $true
Invoke-Step 'gate-licensed-contract' 'scripts\tests\test_licensed_contract.ps1' $true
Invoke-Step 'gate-no-secrets-in-archive' 'scripts\tests\test_no_secrets_in_archive.ps1' $true
Invoke-Step 'gate-crosscheck-integrity' 'scripts\tests\test_crosscheck_integrity.ps1' $true   # fatal on conversion error / history pollution; tolerates source outage
Invoke-Step 'gate-synthesis-fixtures' 'scripts\tests\test_synthesis_fixtures.ps1' $true    # fatal since Mission 7
Invoke-Step 'gate-synthesis-stability' 'scripts\tests\test_synthesis_stability.ps1' $true   # fatal since Mission 7

# ---------- 3. qa-checks (inline, fatal) ----------
# 3a. secrets scan over emitted dashboard text artifacts
$secretHits = New-Object System.Collections.Generic.List[string]
$secretPatterns = @('api_key=(?!\{KEY\})[A-Za-z0-9]{10,}', '\bAKIA[0-9A-Z]{16}\b', 'Bearer\s+[A-Za-z0-9\-_\.]{20,}', '\b[a-f0-9]{32}\b')
foreach ($f in @(Get-ChildItem $dashDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.js', '.html') })) {
  $txt = Get-Content $f.FullName -Raw -Encoding UTF8
  foreach ($pat in $secretPatterns) {
    if ($txt -match $pat) { $secretHits.Add(($f.Name + ' matches ' + $pat)) }
  }
}
if ($secretHits.Count -gt 0) { Add-Step 'qa-secrets-scan' 'FAILURE' $true ($secretHits -join '; ') }
else { Add-Step 'qa-secrets-scan' 'PASS' $true 'no key-shaped content in emitted artifacts' }

# 3b. numeric-history scan (no fabricated/synthetic/non-numeric values in history)
$histPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$histIssues = New-Object System.Collections.Generic.List[string]
$histRows = 0
$seenKeys = @{}
if (-not (Test-Path $histPath)) { $histIssues.Add('history store missing') }
else {
  foreach ($h in (Import-Csv $histPath)) {
    $histRows++
    if (([string]$h.date) -notmatch '^\d{4}-\d{2}(-\d{2})?$') { $histIssues.Add(($h.row_id + ': bad date ' + $h.date)) }
    $d = [double]0
    if (-not [double]::TryParse([string]$h.value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { $histIssues.Add(($h.row_id + ': non-numeric value at ' + $h.date)) }
    elseif ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { $histIssues.Add(($h.row_id + ': non-finite value at ' + $h.date)) }
    $k = $h.row_id + '|' + $h.date
    if ($seenKeys.ContainsKey($k)) { $histIssues.Add(('duplicate observation ' + $k)) } else { $seenKeys[$k] = $true }
    if ($histIssues.Count -gt 20) { break }
  }
}
if ($histIssues.Count -gt 0) { Add-Step 'qa-numeric-history' 'FAILURE' $true (($histIssues | Select-Object -First 5) -join '; ') }
else { Add-Step 'qa-numeric-history' 'PASS' $true ("{0} observations, all castable, finite, unique" -f $histRows) }

# 3c. ratcheted baselines (floors carried in manifest; regression fatal; floors rise)
$manifestPath = Join-Path $dashDir 'build_manifest.json'
$floorCaptured = 0; $floorCharted = 0
if (Test-Path $manifestPath) {
  try {
    $prev = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $floorCaptured = [int]$prev.baselines.captured_floor
    $floorCharted = [int]$prev.baselines.charted_floor
  } catch { }
}
$dataRaw = Get-Content (Join-Path $dashDir 'data.js') -Raw -Encoding UTF8
$dataObj = $dataRaw.Substring($dataRaw.IndexOf('{')).TrimEnd().TrimEnd(';') | ConvertFrom-Json
$curCaptured = [int]$dataObj.counts.captured
$curCharted = [int]$dataObj.counts.charted
if ($curCaptured -lt $floorCaptured -or $curCharted -lt $floorCharted) {
  Add-Step 'qa-ratchet' 'FAILURE' $true ("captured {0} (floor {1}) / charted {2} (floor {3}) - regression" -f $curCaptured, $floorCaptured, $curCharted, $floorCharted)
} else {
  Add-Step 'qa-ratchet' 'PASS' $true ("captured {0} (floor {1}) / charted {2} (floor {3})" -f $curCaptured, $floorCaptured, $curCharted, $floorCharted)
}
$newFloorCaptured = [math]::Max($floorCaptured, $curCaptured)
$newFloorCharted = [math]::Max($floorCharted, $curCharted)

# ---------- 4. data freshness (per-row staleness vs budget; WARN named, 2x escalates) ----------
function Budget-Days([string]$b) {
  if ($b -match '^(\d+)([dwmq])$') {
    $n = [int]$Matches[1]
    switch ($Matches[2]) { 'd' { return $n } 'w' { return $n * 7 } 'm' { return $n * 31 } 'q' { return $n * 93 } }
  }
  return 0
}
$reg = @(Import-Csv (Get-NewestRegistry (Join-Path $base 'registry')).FullName)
$staleWarn = New-Object System.Collections.Generic.List[string]
$staleEsc = New-Object System.Collections.Generic.List[string]
$freshCount = 0
$inv = [System.Globalization.CultureInfo]::InvariantCulture
foreach ($p in $dataObj.series.PSObject.Properties) {
  $id = $p.Name
  $lastStr = [string]@($p.Value.obs)[-1][0]
  if ($lastStr -match '^\d{4}-\d{2}$') { $lastStr = $lastStr + '-01' }
  $last = [datetime]::ParseExact($lastStr, 'yyyy-MM-dd', $inv)
  $bd = Budget-Days ([string]$p.Value.meta.staleness_budget)
  $ageDays = ([datetime]::UtcNow - $last).TotalDays
  # monthly/quarterly periods date from period START; budget map already allows a full
  # publication cycle, so age is measured plainly and the budget absorbs the lag.
  if ($bd -gt 0 -and $ageDays -gt (2 * $bd)) { $staleEsc.Add(("{0} (age {1:0}d, budget {2})" -f $id, $ageDays, $p.Value.meta.staleness_budget)) }
  elseif ($bd -gt 0 -and $ageDays -gt $bd) { $staleWarn.Add(("{0} (age {1:0}d, budget {2})" -f $id, $ageDays, $p.Value.meta.staleness_budget)) }
  else { $freshCount++ }
}
$freshDetail = ("fresh {0}; stale-warn {1}; escalated {2}" -f $freshCount, $staleWarn.Count, $staleEsc.Count)
if ($staleEsc.Count -gt 0) { Add-Step 'data-freshness' 'ESCALATED' $false ($freshDetail + ' | ESCALATED: ' + ($staleEsc -join ', ')) }
elseif ($staleWarn.Count -gt 0) { Add-Step 'data-freshness' 'WARN' $false ($freshDetail + ' | stale: ' + ($staleWarn -join ', ')) }
else { Add-Step 'data-freshness' 'PASS' $false $freshDetail }

# ---------- 5. overall + manifest ----------
$fatalFailures = @($steps | Where-Object { $_.fatal -and $_.status -eq 'FAILURE' })
$overall = 'PASS'
if (@($fatalFailures).Count -gt 0) { $overall = 'FAILURE' }

$hashes = [ordered]@{}
foreach ($f in (Get-ChildItem $dashDir -File | Where-Object { $_.Name -notin @('build_manifest.json', 'build_manifest.js') } | Sort-Object Name)) {
  $hashes[$f.Name] = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
}
$gateStatuses = [ordered]@{}
foreach ($s in $steps) { $gateStatuses[$s.step] = $s.status }
$manifest = [ordered]@{
  BUILD_STATUS = $overall
  generated_utc = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  registry_version = [string]$dataObj.registry_version
  baselines = [ordered]@{ captured_floor = $newFloorCaptured; charted_floor = $newFloorCharted }
  counts = [ordered]@{
    selected = [int]$dataObj.counts.selected; captured = $curCaptured; charted = $curCharted
    latest_only = [int]$dataObj.counts.latest_only; not_captured = [int]$dataObj.counts.not_captured
  }
  gates = $gateStatuses
  freshness = [ordered]@{ fresh = $freshCount; stale_warn = @($staleWarn); escalated = @($staleEsc) }
  artifact_hashes_sha256 = $hashes
}
$manifestJson = $manifest | ConvertTo-Json -Depth 6
$manifestJson | Set-Content -Path $manifestPath -Encoding UTF8
# offline-loadable mirror for the file:// footer (fetch of local JSON is CORS-blocked)
[System.IO.File]::WriteAllText((Join-Path $dashDir 'build_manifest.js'), ('window.BUILD_MANIFEST = ' + $manifestJson + ';'), (New-Object System.Text.UTF8Encoding($false)))
Add-Step 'manifest' 'PASS' $false ("BUILD_STATUS={0}; {1} artifact hashes" -f $overall, $hashes.Keys.Count)

# ---------- 6. freshness audit log (contract schema) + run summary ----------
$audit = @()
$auditPath = Join-Path $logsDir 'source_refresh_audit.csv'
if (Test-Path $auditPath) { $audit = @(Import-Csv $auditPath) }
$attempted = @($audit | Where-Object { $_.attempted_this_run -eq 'True' })
$freshRows = @($attempted | Where-Object { $_.fetch_succeeded -eq 'True' })
$keptPrior = @($attempted | Where-Object { $_.history_source -eq 'kept-prior' })
$obsFetched = 0
foreach ($a in $freshRows) { $obsFetched += [int]$a.observations_fetched }
$famGroups = @($attempted | Group-Object source_family)
$famOk = [int]@($famGroups | Where-Object { @($_.Group | Where-Object { $_.fetch_succeeded -eq 'True' }).Count -gt 0 }).Count
$famFail = [int](@($famGroups).Count - $famOk)
$capDirs = Get-ChildItem (Join-Path $base 'raw_archive\capture') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
$rawFiles = 0
if ($capDirs) { $rawFiles = [int]@(Get-ChildItem $capDirs[0].FullName -File).Count }
$runEnv = 'local'
$runnerMarker = ('host=' + $env:COMPUTERNAME)
if ($env:GITHUB_ACTIONS -eq 'true') {
  $runEnv = 'github_actions'
  $runnerMarker = ('runner=GitHub Actions; os=' + $env:RUNNER_OS + '; run_id=' + $env:GITHUB_RUN_ID + '; sha=' + $env:GITHUB_SHA)
}
$freshLog = Join-Path $logsDir 'cloud_refresh_freshness_log.csv'
$freshRow = [pscustomobject]@{
  generated = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'); run_environment = $runEnv; runner_marker = $runnerMarker
  overall = $overall; captured = $curCaptured; charted = $curCharted
  latest_only = [int]$dataObj.counts.latest_only; not_captured = [int]$dataObj.counts.not_captured
  fetches_attempted = [int]@($attempted).Count; rows_fresh_from_source = [int]@($freshRows).Count
  rows_kept_prior = [int]@($keptPrior).Count; observations_fetched = $obsFetched; raw_files_written = $rawFiles
  families_attempted = [int]@($famGroups).Count; families_succeeded = $famOk; families_failed = $famFail
  capture_started_at_utc = $captureStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
  capture_completed_at_utc = $captureEndUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
  kept_prior_row_ids = (@($keptPrior | ForEach-Object { $_.row_id }) -join ';')
}
if (-not (Test-Path $freshLog)) { $freshRow | Export-Csv -Path $freshLog -NoTypeInformation -Encoding UTF8 }
else {
  $freshRow | Export-Csv -Path ($freshLog + '.tmp') -NoTypeInformation -Encoding UTF8
  Get-Content ($freshLog + '.tmp') | Select-Object -Skip 1 | Add-Content -Path $freshLog -Encoding UTF8
  Remove-Item ($freshLog + '.tmp')
}

$endIso = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$summary = [ordered]@{
  generated = $endIso; started = $startIso; overall = $overall
  baseline = [ordered]@{ captured = $newFloorCaptured; charted = $newFloorCharted }
  counts = [ordered]@{
    captured = $curCaptured; charted = $curCharted; latest_only = [int]$dataObj.counts.latest_only
    history_obs = $histRows; not_captured = [int]$dataObj.counts.not_captured
    history_series = [int]@($dataObj.series.PSObject.Properties).Count
  }
  capture = [ordered]@{ captured = [int]@($freshRows).Count; failed_kept_prior = [int]@($keptPrior).Count; wired = [int]@($attempted).Count }
  freshness = [ordered]@{
    run_environment = $runEnv; runner_marker = $runnerMarker
    refresh_started_at_utc = $startIso
    capture_started_at_utc = $captureStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    capture_completed_at_utc = $captureEndUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    build_started_at_utc = $buildStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    build_completed_at_utc = $buildEndUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    source_families_attempted = [int]@($famGroups).Count
    source_families_succeeded = $famOk; source_families_failed = $famFail
    fetches_attempted = [int]@($attempted).Count; raw_files_written = $rawFiles
    observations_fetched = $obsFetched
    rows_fresh_from_source = [int]@($freshRows).Count; rows_kept_prior = [int]@($keptPrior).Count
    kept_prior_row_ids = @($keptPrior | ForEach-Object { $_.row_id })
  }
  gates = $gateStatuses
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $logsDir 'refresh_run_summary.json') -Encoding UTF8
$md = @('# commodity dashboard refresh run summary', '', ("**Overall: {0}**  -  generated {1}" -f $overall, $endIso), '', '| step | status | detail |', '|---|---|---|')
foreach ($s in $steps) { $md += ("| {0} | {1} | {2} |" -f $s.step, $s.status, ($s.detail -replace '\|', '/')) }
$md += ''
$md += ("counts: captured {0} / charted {1} / floors {2}/{3} / history obs {4}" -f $curCaptured, $curCharted, $newFloorCaptured, $newFloorCharted, $histRows)
$md -join "`n" | Set-Content -Path (Join-Path $logsDir 'refresh_run_summary.md') -Encoding UTF8

Write-Host ''
Write-Host ("=== refresh_all OVERALL: {0} ===" -f $overall)
if ($overall -ne 'PASS') { exit 1 }
exit 0
