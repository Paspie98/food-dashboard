# test_synthesis_stability.ps1 — Mission 7 fatal gate. Replays the full state log
# through the hysteresis machine: every logged published state must be reproduced
# (persistence rule inviolable), and the emitted synthesis.js must match the log tail.
# Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $testDir
$base = Split-Path -Parent $scriptsDir
. (Join-Path $scriptsDir 'synthesis_rules.ps1')
$fails = New-Object System.Collections.Generic.List[string]

$logPath = Join-Path $base 'logs\synthesis_state_log.csv'
if (-not (Test-Path $logPath)) { Write-Host 'FAIL: synthesis_state_log.csv missing (no read ever published)'; exit 1 }
$log = @(Import-Csv $logPath)
if (@($log).Count -eq 0) { Write-Host 'FAIL: state log empty'; exit 1 }

# ---- 1. replay: published states must re-derive from raw sequence ----
$replayed = 0
foreach ($unitGroup in ($log | Group-Object unit)) {
  $unit = $unitGroup.Name
  $rowsAsc = @($unitGroup.Group | Sort-Object month)
  $prior = @()
  foreach ($row in $rowsAsc) {
    $h = Resolve-CmdHysteresis -PriorRows $prior -Month ([string]$row.month) -Raw ([string]$row.raw_state)
    if ([string]$h.published -ne [string]$row.published_state) {
      $fails.Add(("{0} {1}: replay computes published={2}, log says {3}" -f $unit, $row.month, $h.published, $row.published_state))
    }
    if ([string]$h.candidate -ne [string]$row.candidate_state -or [int]$h.streak -ne [int]$row.candidate_streak) {
      $fails.Add(("{0} {1}: replay candidate ({2},{3}) vs log ({4},{5})" -f $unit, $row.month, $h.candidate, $h.streak, $row.candidate_state, $row.candidate_streak))
    }
    $replayed++
    $prior = @($prior) + @($row)
  }
}
Write-Host ("replayed {0} log rows across {1} units" -f $replayed, @(@($log | Group-Object unit)).Count)

# ---- 2. emitted synthesis.js must equal the log tail for its month ----
$synthPath = Join-Path $base 'dashboard\synthesis.js'
if (-not (Test-Path $synthPath)) { $fails.Add('dashboard/synthesis.js missing') }
else {
  $raw = Get-Content $synthPath -Raw -Encoding UTF8
  $braceIdx = $raw.IndexOf('{')
  if ($braceIdx -lt 0) { $fails.Add('synthesis.js holds no payload (placeholder?)') }
  else {
    $s = $raw.Substring($braceIdx).TrimEnd().TrimEnd(';') | ConvertFrom-Json
    foreach ($p in $s.units.PSObject.Properties) {
      $unit = $p.Name
      $logged = @($log | Where-Object { $_.unit -eq $unit -and $_.month -eq [string]$s.month })
      if (@($logged).Count -ne 1) { $fails.Add(("{0}: no single log row for emitted month {1}" -f $unit, $s.month)); continue }
      if ([string]$logged[0].published_state -ne [string]$p.Value.published) {
        $fails.Add(("{0}: synthesis.js published={1} but log says {2}" -f $unit, $p.Value.published, $logged[0].published_state))
      }
    }
  }
}

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (synthesis stability - persistence inviolable, emission matches log)'; exit 0
