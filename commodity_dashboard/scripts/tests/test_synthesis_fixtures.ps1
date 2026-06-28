# test_synthesis_fixtures.ps1 — Mission 7 fatal gate. Pure-function fixtures over
# synthesis_rules.ps1 (the same file the engine ships). Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $testDir) 'synthesis_rules.ps1')
$fails = New-Object System.Collections.Generic.List[string]
function Check([string]$name, [bool]$cond) {
  if ($cond) { Write-Host ("  ok: {0}" -f $name) } else { $script:fails.Add($name); Write-Host ("  FAIL: {0}" -f $name) }
}
function VoteRow($w, $v, [bool]$stale) { return [pscustomobject]@{ weight = $w; vote = $v; stale = $stale } }

Write-Host '--- direction class ---'
Check 'level up'        ((Get-CmdDirClass 'level' 6.6 1.8) -eq 'up')
Check 'level down'      ((Get-CmdDirClass 'level' -7.3 -30.0) -eq 'down')
Check 'level flat'      ((Get-CmdDirClass 'level' 1.1 0.5) -eq 'flat')
Check 'level mixed up3 down12 (cocoa case)' ((Get-CmdDirClass 'level' 15.9 -53.7) -eq 'mixed')
Check 'level mixed down3 up12' ((Get-CmdDirClass 'level' -9.7 12.8) -eq 'mixed')
Check 'index point threshold flat' ((Get-CmdDirClass 'index' -0.2 -22.4) -eq 'flat')
Check 'index up'        ((Get-CmdDirClass 'index' 5.6 4.9) -eq 'up')
Check 'null d3 -> flat' ((Get-CmdDirClass 'level' $null 50) -eq 'flat')
Check 'string inputs cast' ((Get-CmdDirClass 'level' '6.6' '1.8') -eq 'up')

Write-Host '--- votes (pressure mode) ---'
Check 'up -> +1'    ((Get-CmdRowVote 'up') -eq 1)
Check 'down -> -1'  ((Get-CmdRowVote 'down') -eq -1)
Check 'flat -> 0'   ((Get-CmdRowVote 'flat') -eq 0)
Check 'mixed -> 0'  ((Get-CmdRowVote 'mixed') -eq 0)

Write-Host '--- layer read states (every state reachable) ---'
$r = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 1 $false), (VoteRow 2 1 $false), (VoteRow 1 1 $false))
Check 'escalating (unanimous)' ($r.raw -eq 'escalating')
$r = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 1 $false), (VoteRow 2 -1 $false), (VoteRow 2 0 $false))
Check 'tightening (score .25, breadth .5)' ($r.raw -eq 'tightening')
$r = Get-CmdLayerRead @((VoteRow 2 -1 $false), (VoteRow 2 -1 $false), (VoteRow 2 1 $false))
Check 'easing' ($r.raw -eq 'easing')
$r = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 -1 $false), (VoteRow 2 0 $false))
Check 'stable' ($r.raw -eq 'stable')
$r = Get-CmdLayerRead @((VoteRow 2 1 $false))
Check 'insufficient-data (<2 voters)' ($r.raw -eq 'insufficient-data')
$r = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 1 $false), (VoteRow 0 0 $true), (VoteRow 0 0 $true), (VoteRow 0 0 $true))
Check 'insufficient-data (freshShare 0.4)' ($r.raw -eq 'insufficient-data')

Write-Host '--- supermajority clause ---'
$r = Get-CmdLayerRead @((VoteRow 6 1 $false), (VoteRow 0.4 -1 $false), (VoteRow 2.5 0 $false))
Check 'score .63 but breadth .67 -> tightening not escalating' ($r.raw -eq 'tightening')
$r = Get-CmdLayerRead @((VoteRow 6 1 $false), (VoteRow 0.4 -1 $false), (VoteRow 1.0 0 $false))
Check 'score .76 breadth .81 -> escalating' ($r.raw -eq 'escalating')

Write-Host '--- neutral voting + casting regression ---'
$r = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 1 $false), (VoteRow 0 0 $true))
Check 'stale row is not a voter' ($r.voters -eq 2)
$rs = Get-CmdLayerRead @((VoteRow '2' '1' $false), (VoteRow '2' '-1' $false), (VoteRow '1' '0' $false))
$rn = Get-CmdLayerRead @((VoteRow 2 1 $false), (VoteRow 2 -1 $false), (VoteRow 1 0 $false))
Check 'STRING votes/weights compute identically to numeric (string-multiply bug class)' (($rs.score -eq $rn.score) -and ($rs.raw -eq $rn.raw) -and ($rs.score -eq 0))

Write-Host '--- hysteresis h1-h5 (+ initial, availability, return) ---'
function LogRow([string]$m, [string]$pub, [string]$cand, [int]$st) {
  return [pscustomobject]@{ month = $m; published_state = $pub; candidate_state = $cand; candidate_streak = $st }
}
$h = Resolve-CmdHysteresis @() '2026-05' 'tightening'
Check 'initial publishes raw with action=initial' (($h.published -eq 'tightening') -and ($h.action -eq 'initial'))
$h = Resolve-CmdHysteresis @((LogRow '2026-03' 'stable' '' 0)) '2026-04' 'tightening'
Check 'h1: first divergent month -> candidate, no flip' (($h.published -eq 'stable') -and ($h.candidate -eq 'tightening') -and ($h.streak -eq 1))
$h = Resolve-CmdHysteresis @((LogRow '2026-03' 'stable' '' 0), (LogRow '2026-04' 'stable' 'tightening' 1)) '2026-05' 'tightening'
Check 'h2: second distinct month -> FLIP' (($h.published -eq 'tightening') -and ($h.action -eq 'flip'))
$h = Resolve-CmdHysteresis @((LogRow '2026-03' 'stable' '' 0), (LogRow '2026-04' 'stable' 'tightening' 1)) '2026-05' 'stable'
Check 'h3: candidate interrupted -> cleared, hold' (($h.published -eq 'stable') -and ($h.candidate -eq '') -and ($h.streak -eq 0))
$h = Resolve-CmdHysteresis @((LogRow '2026-04' 'stable' 'tightening' 1)) '2026-04' 'escalating'
Check 'h4: same-month rebuild NEVER flips' (($h.published -eq 'stable') -and ($h.action -eq 'same-month-noop') -and ($h.candidate -eq 'tightening'))
$h = Resolve-CmdHysteresis @((LogRow '2026-03' 'stable' '' 0), (LogRow '2026-04' 'stable' 'tightening' 1)) '2026-05' 'easing'
Check 'h5: candidate retarget resets streak to 1' (($h.published -eq 'stable') -and ($h.candidate -eq 'easing') -and ($h.streak -eq 1))
$h = Resolve-CmdHysteresis @((LogRow '2026-04' 'tightening' '' 0)) '2026-05' 'insufficient-data'
Check 'availability bypass publishes insufficient-data immediately' (($h.published -eq 'insufficient-data') -and ($h.action -eq 'availability'))
$h = Resolve-CmdHysteresis @((LogRow '2026-03' 'tightening' '' 0), (LogRow '2026-04' 'insufficient-data' '' 0)) '2026-05' 'easing'
Check 'return from insufficient resumes from last real state' (($h.published -eq 'tightening') -and ($h.candidate -eq 'easing') -and ($h.streak -eq 1))

Write-Host '--- diverging + language gates ---'
Check 'diverging true (input hot, products calm)' (Get-CmdDiverging -InputStates @('stable','tightening') -ProductStates @('stable','easing'))
Check 'diverging false when a product hot' (-not (Get-CmdDiverging -InputStates @('escalating','stable') -ProductStates @('stable','tightening')))
Check 'confidence text passes language gate' (-not (Test-CmdBannedLanguage (Get-CmdConfidence 3 @('FE-006') 0.8)))
Check 'positive fixture: dramatic term flagged' (Test-CmdBannedLanguage 'prices may skyrocket next month')
Check 'positive fixture: causal phrasing flagged' (Test-CmdBannedLanguage 'higher gas prices will push urea up because of feedstock costs')
Check 'neutral sentence passes' (-not (Test-CmdBannedLanguage 'urea rose 8.4% over the 3 months to May 2026'))

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); exit 1 }
Write-Host 'RESULT: PASS (synthesis fixtures)'; exit 0
