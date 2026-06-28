# build_synthesis.ps1 — Mission 7 engine (spec: docs/synthesis_spec.md).
# Consumes captured history + newest registry; rules from synthesis_rules.ps1 (pure,
# fixtures-gated). Emits dashboard/synthesis.js and appends logs/synthesis_state_log.csv
# idempotently. Exit 1 on: same-month published drift, banned/causal language in
# generated text, or engine error. PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')
. (Join-Path $scriptDir 'synthesis_rules.ps1')

$historyPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$logPath = Join-Path $base 'logs\synthesis_state_log.csv'
$outPath = Join-Path $base 'dashboard\synthesis.js'
if (-not (Test-Path $historyPath)) { throw 'no captured history' }
$inv = [System.Globalization.CultureInfo]::InvariantCulture

$reg = @(Import-Csv (Get-NewestRegistry (Join-Path $base 'registry')).FullName)
$hist = @{}
foreach ($h in (Import-Csv $historyPath)) {
  if (-not $hist.ContainsKey($h.row_id)) { $hist[$h.row_id] = New-Object System.Collections.Generic.List[object] }
  $hist[$h.row_id].Add(@{ d = [string]$h.date; v = [double]$h.value })
}
foreach ($k in @($hist.Keys)) { $hist[$k] = [object[]]@($hist[$k] | Sort-Object { $_.d }) }

# ---------- synthesis month = last FULL calendar month (UTC) ----------
$nowUtc = [datetime]::UtcNow
$M = (New-Object datetime($nowUtc.Year, $nowUtc.Month, 1)).AddMonths(-1).ToString('yyyy-MM')

function MonthShift([string]$ym, [int]$k) {
  return [datetime]::ParseExact($ym + '-01', 'yyyy-MM-dd', $inv).AddMonths($k).ToString('yyyy-MM')
}
function EndOfMonth([string]$ym) {
  return [datetime]::ParseExact($ym + '-01', 'yyyy-MM-dd', $inv).AddMonths(1).AddDays(-1)
}
function BudgetDays([string]$b) {
  if ($b -match '^(\d+)([dwmq])$') {
    $n = [int]$Matches[1]
    switch ($Matches[2]) { 'd' { return $n } 'w' { return $n * 7 } 'm' { return $n * 31 } 'q' { return $n * 93 } }
  }
  return 0
}
function ObsDate([string]$d) {
  if ($d.Length -eq 7) { return [datetime]::ParseExact($d + '-01', 'yyyy-MM-dd', $inv) }
  return [datetime]::ParseExact($d, 'yyyy-MM-dd', $inv)
}
function ValueAt {
  # spec §2: last obs <= end-of-M, within the row's staleness budget from end-of-M
  param([object[]]$Obs, [string]$Ym, [int]$BudgetD)
  $eom = EndOfMonth $Ym
  $best = $null
  foreach ($o in $Obs) {
    $od = ObsDate ([string]$o.d)
    if ($od -le $eom) { $best = $o } else { break }
  }
  if ($null -eq $best) { return $null }
  if (($eom - (ObsDate ([string]$best.d))).TotalDays -gt $BudgetD) { return $null }
  return $best
}
function StrictMonthVal {
  # volatility sampling: observation INSIDE the month only (no carry)
  param([object[]]$Obs, [string]$Ym)
  $best = $null
  foreach ($o in $Obs) {
    $p = ([string]$o.d)
    if ($p.Length -ge 7 -and $p.Substring(0, 7) -eq $Ym) { $best = $o }
  }
  return $best
}
function Median([double[]]$xs) {
  $s = @($xs | Sort-Object)
  $n = @($s).Count
  if ($n -eq 0) { return $null }
  if ($n % 2 -eq 1) { return [double]$s[[int][math]::Floor($n / 2)] }
  return ([double]$s[$n / 2 - 1] + [double]$s[$n / 2]) / 2.0
}

# ---------- per-row votes + evidence ----------
$rows = @($reg | Where-Object { $_.data_class -eq 'realised' -and $_.chartable -eq 'yes' -and $hist.ContainsKey($_.row_id) })
$evidence = @{}
foreach ($r in $rows) {
  $obs = $hist[$r.row_id]
  $bd = BudgetDays ([string]$r.staleness_budget)
  $basis = 'level'; if ($r.unit -eq 'index') { $basis = 'index' }
  $v0 = ValueAt $obs $M $bd
  $v3 = ValueAt $obs (MonthShift $M -3) $bd
  $v12 = ValueAt $obs (MonthShift $M -12) $bd
  $stale = ($null -eq $v0)
  $d3 = $null; $d12 = $null; $d3pct = $null
  if (-not $stale -and $null -ne $v3 -and [double]$v3.v -ne 0) {
    if ($basis -eq 'index') { $d3 = [math]::Round([double]$v0.v - [double]$v3.v, 2) } else { $d3 = [math]::Round(([double]$v0.v / [double]$v3.v - 1) * 100, 2) }
    $d3pct = [math]::Round(([double]$v0.v / [double]$v3.v - 1) * 100, 2)
  }
  if (-not $stale -and $null -ne $v12 -and [double]$v12.v -ne 0) {
    if ($basis -eq 'index') { $d12 = [math]::Round([double]$v0.v - [double]$v12.v, 2) } else { $d12 = [math]::Round(([double]$v0.v / [double]$v12.v - 1) * 100, 2) }
  }
  $dirClass = 'flat'
  if (-not $stale) { $dirClass = Get-CmdDirClass -Basis $basis -D3 $d3 -D12 $d12 }
  $vote = [int](Get-CmdRowVote -DirClass $dirClass)
  $weight = 2
  if ($basis -eq 'index') { $weight = 1 }
  if ($stale) { $weight = 0; $vote = 0 }
  $evidence[$r.row_id] = [pscustomobject]@{
    row_id = $r.row_id; layer = [string]$r.layer; title = [string]$r.series_name
    basis = $basis; weight = [int]$weight; vote = [int]$vote; dir = $dirClass
    d3 = $d3; d12 = $d12; d3pct = $d3pct; stale = [bool]$stale
  }
}

# ---------- unit reads ----------
$unitDefs = [ordered]@{
  'S1' = @($rows | Where-Object { $_.segment -eq 'S1' } | ForEach-Object { $_.row_id })
  'S2' = @($rows | Where-Object { $_.segment -eq 'S2' } | ForEach-Object { $_.row_id })
  'S3' = @($rows | Where-Object { $_.segment -eq 'S3' } | ForEach-Object { $_.row_id })
  'S4' = @($rows | Where-Object { $_.segment -eq 'S4' } | ForEach-Object { $_.row_id })
  'S5' = @($rows | Where-Object { $_.segment -eq 'S5' } | ForEach-Object { $_.row_id })
  'composite' = @($rows | ForEach-Object { $_.row_id })
}

$priorLog = @()
if (Test-Path $logPath) { $priorLog = @(Import-Csv $logPath) }

$unitsOut = [ordered]@{}
$newLogRows = New-Object System.Collections.Generic.List[object]
$violations = New-Object System.Collections.Generic.List[string]
$publishedByUnit = @{}

foreach ($unit in $unitDefs.Keys) {
  $ids = @($unitDefs[$unit])
  $ev = @($ids | ForEach-Object { $evidence[$_] })
  $read = Get-CmdLayerRead -Rows $ev
  $staleNames = @($ev | Where-Object { $_.stale } | ForEach-Object { $_.row_id })
  $mom = Median (@($ev | Where-Object { $_.weight -gt 0 -and $null -ne $_.d3pct } | ForEach-Object { [double]$_.d3pct }))
  if ($null -ne $mom) { $mom = [math]::Round([double]$mom, 1) }
  # volatility regime: strict in-month MoM% samples, trailing 12m vs prior 12m
  $cur = New-Object System.Collections.Generic.List[double]
  $pri = New-Object System.Collections.Generic.List[double]
  foreach ($id in $ids) {
    $obs = $hist[$id]
    for ($k = 0; $k -lt 24; $k++) {
      $mA = StrictMonthVal $obs (MonthShift $M (-1 * $k))
      $mB = StrictMonthVal $obs (MonthShift $M (-1 * ($k + 1)))
      if ($null -ne $mA -and $null -ne $mB -and [double]$mB.v -ne 0) {
        $mom1 = [math]::Abs(([double]$mA.v / [double]$mB.v - 1) * 100)
        if ($k -lt 12) { $cur.Add([double]$mom1) } else { $pri.Add([double]$mom1) }
      }
    }
  }
  $vol = 'n/a'
  if ($cur.Count -ge 6 -and $pri.Count -ge 6) {
    $mc = Median $cur.ToArray(); $mp = Median $pri.ToArray()
    if ($null -ne $mc -and $null -ne $mp -and [double]$mp -gt 0) {
      if (([double]$mc) -gt 1.5 * ([double]$mp)) { $vol = 'elevated' } else { $vol = 'normal' }
    }
  }
  $prior = @($priorLog | Where-Object { $_.unit -eq $unit })
  $hys = Resolve-CmdHysteresis -PriorRows $prior -Month $M -Raw $read.raw
  $publishedByUnit[$unit] = [string]$hys.published
  $note = ''
  if ($hys.action -eq 'initial') { $note = 'initial' }
  elseif ($hys.action -eq 'streak' -or $hys.action -eq 'candidate') { $note = ('candidate ' + $hys.candidate + ' (streak ' + $hys.streak + ' of 2 distinct months)') }
  $conf = Get-CmdConfidence -Voters $read.voters -StaleNames $staleNames -FreshShare $read.freshShare
  foreach ($txt in @($note, $conf)) {
    if (Test-CmdBannedLanguage -Text $txt) { $violations.Add(("{0}: banned/causal language in generated text: {1}" -f $unit, $txt)) }
  }
  $unitsOut[$unit] = [pscustomobject]@{
    read = $read; hys = $hys; note = $note; conf = $conf; mom = $mom; vol = $vol
    staleNames = $staleNames; evidence = $ev
  }
}

# composite diverging modifier (after all units resolved)
$diverging = Get-CmdDiverging -InputStates @($publishedByUnit['S1'], $publishedByUnit['S4']) -ProductStates @($publishedByUnit['S2'], $publishedByUnit['S3'])
if ($diverging) {
  $u = $unitsOut['composite']
  $dnote = 'diverging: farm-input or energy layer under cost pressure while raw-crop and processed-ingredient layers hold - structural drag watch'
  if (Test-CmdBannedLanguage -Text $dnote) { $violations.Add('composite: diverging note fails language gate') }
  if ($u.note -ne '') { $u.note = $u.note + '; ' + $dnote } else { $u.note = $dnote }
}

if ($violations.Count -gt 0) {
  Write-Host 'SYNTHESIS LANGUAGE VIOLATIONS:'; foreach ($v in $violations) { Write-Host (' - ' + $v) }; exit 1
}

# ---------- state log: idempotent append; same-month drift is fatal ----------
$logCols = 'month,unit,raw_state,published_state,candidate_state,candidate_streak,score,breadth_pct,momentum_3m_med,voters,stale_voters,note'
foreach ($unit in $unitsOut.Keys) {
  $u = $unitsOut[$unit]
  $existing = @($priorLog | Where-Object { $_.unit -eq $unit -and $_.month -eq $M })
  if (@($existing).Count -gt 0) {
    if ([string]$existing[0].published_state -ne [string]$u.hys.published) {
      Write-Host ("FATAL: same-month rebuild would flip {0} {1}: logged {2} vs computed {3}" -f $unit, $M, $existing[0].published_state, $u.hys.published)
      exit 1
    }
    continue   # already logged; append nothing
  }
  $newLogRows.Add([pscustomobject]@{
    month = $M; unit = $unit; raw_state = [string]$u.read.raw; published_state = [string]$u.hys.published
    candidate_state = [string]$u.hys.candidate; candidate_streak = [int]$u.hys.streak
    score = [double]$u.read.score; breadth_pct = [math]::Round(100 * [double]$u.read.breadth, 1)
    momentum_3m_med = $u.mom; voters = [int]$u.read.voters
    stale_voters = (@($u.staleNames) -join ';'); note = [string]$u.note
  })
}
if ($newLogRows.Count -gt 0) {
  if (-not (Test-Path $logPath)) { $newLogRows | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8 }
  else {
    $newLogRows | Export-Csv -Path ($logPath + '.tmp') -NoTypeInformation -Encoding UTF8
    Get-Content ($logPath + '.tmp') | Select-Object -Skip 1 | Add-Content -Path $logPath -Encoding UTF8
    Remove-Item ($logPath + '.tmp')
  }
}

# ---------- emit synthesis.js (deterministic hand-rolled JSON) ----------
function JEsc([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace '\\', '\\\\'; $s = $s -replace '"', '\"'
  return ($s -replace "`r", '' -replace "`n", ' ')
}
function JNum($v) { if ($null -eq $v -or ([string]$v) -eq '') { return 'null' }; return ([double]$v).ToString($inv) }
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('window.SYNTHESIS = {"month":"' + $M + '","generated_utc":"' + $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ') + '","units":{')
$firstU = $true
foreach ($unit in $unitsOut.Keys) {
  $u = $unitsOut[$unit]
  if (-not $firstU) { [void]$sb.Append(',') }
  $firstU = $false
  [void]$sb.Append('"' + $unit + '":{')
  [void]$sb.Append('"published":"' + (JEsc $u.hys.published) + '","raw":"' + (JEsc $u.read.raw) + '",')
  [void]$sb.Append('"score":' + (JNum $u.read.score) + ',"breadth":' + (JNum $u.read.breadth) + ',')
  [void]$sb.Append('"momentum_3m_med":' + (JNum $u.mom) + ',"volatility":"' + (JEsc $u.vol) + '",')
  [void]$sb.Append('"voters":' + [int]$u.read.voters + ',"fresh_share":' + (JNum $u.read.freshShare) + ',')
  [void]$sb.Append('"confidence":"' + (JEsc $u.conf) + '","note":"' + (JEsc $u.note) + '",')
  [void]$sb.Append('"stale":[' + ((@($u.staleNames | ForEach-Object { '"' + $_ + '"' })) -join ',') + '],')
  [void]$sb.Append('"evidence":[')
  $firstE = $true
  foreach ($e in ($u.evidence | Sort-Object row_id)) {
    if (-not $firstE) { [void]$sb.Append(',') }
    $firstE = $false
    [void]$sb.Append('{"row_id":"' + $e.row_id + '","title":"' + (JEsc $e.title) + '","weight":' + [int]$e.weight +
      ',"vote":' + [int]$e.vote + ',"dir":"' + $e.dir + '","d3":' + (JNum $e.d3) + ',"d12":' + (JNum $e.d12) +
      ',"basis":"' + $e.basis + '","stale":' + $(if ($e.stale) { 'true' } else { 'false' }) + '}')
  }
  [void]$sb.Append(']}')
}
[void]$sb.Append('}};')
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("synthesis {0}: " -f $M)
foreach ($unit in $unitsOut.Keys) {
  $u = $unitsOut[$unit]
  Write-Host ("  {0}: published={1} raw={2} score={3} breadth={4} mom3m={5}% voters={6} {7}" -f $unit, $u.hys.published, $u.read.raw, $u.read.score, $u.read.breadth, $u.mom, $u.read.voters, $u.note)
}
exit 0
