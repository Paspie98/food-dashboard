# synthesis_rules.ps1 — PURE rule functions for the cost-pressure synthesis
# (docs/synthesis_spec.md §3-§7). Dot-sourced by build_synthesis.ps1 (engine) AND
# test_synthesis_fixtures.ps1 (gate): the tested code IS the shipped code.
# No I/O. Every numeric vote input explicitly [double]-cast at the boundary
# (the "-1" string-multiply vote bug class). PS 5.1 compatible.

$CMD_SYNTH_STATES = @('easing', 'stable', 'tightening', 'escalating', 'insufficient-data')
$CMD_BANNED_TERMS = @('worst since', 'soar', 'skyrocket', 'collapse', 'crisis', 'super el nino',
                      'perfect storm', 'unprecedented', 'plunge', 'explode')
$CMD_CAUSAL_REGEX = '\bwill\b|\bbecause\b|\bdue to\b|\bdriven by\b|\bcauses?\b|\bcaused\b|\bleads? to\b|\bexplains?\b|\bas a result\b'

function Get-CmdDirClass {
  # basis 'level' (threshold ±2.0 %) or 'index' (threshold ±1.0 points).
  # $d3 / $d12 are Δ3m / Δ12m in the basis-native unit (% or points); $null/'' = unknown.
  param([string]$Basis, $D3, $D12)
  $th = 2.0
  if ($Basis -eq 'index') { $th = 1.0 }
  if ($null -eq $D3 -or ([string]$D3) -eq '') { return 'flat' }
  $m3 = [double]$D3
  $m12 = 0.0
  if ($null -ne $D12 -and ([string]$D12) -ne '') { $m12 = [double]$D12 }
  if ([math]::Abs($m3) -lt $th) { return 'flat' }
  if ($m3 -gt 0 -and $m12 -lt (-1 * $th)) { return 'mixed' }
  if ($m3 -lt 0 -and $m12 -gt $th) { return 'mixed' }
  if ($m3 -gt 0) { return 'up' }
  return 'down'
}

function Get-CmdRowVote {
  # cost-pressure mode: rising price = +1 (pressure building), falling = -1 (easing).
  param([string]$DirClass)
  if ($DirClass -eq 'up') { return 1 }
  if ($DirClass -eq 'down') { return -1 }
  return 0
}

function Get-CmdLayerRead {
  # $Rows: objects with {weight, vote, stale}. Stale rows MUST arrive with weight 0
  # (engine contract) — they still count in freshShare's denominator.
  param([object[]]$Rows)
  $rows = @($Rows)
  $wup = 0.0; $wdown = 0.0; $wzero = 0.0
  $voters = 0; $freshN = 0
  foreach ($x in $rows) {
    $isStale = [bool]$x.stale
    if (-not $isStale) { $freshN++ }
    $w = [double]$x.weight     # explicit casts: '2' * '-1' would corrupt as strings
    $v = [double]$x.vote
    if ($w -le 0) { continue }
    $voters++
    if ($v -gt 0) { $wup += $w }
    elseif ($v -lt 0) { $wdown += $w }
    else { $wzero += $w }
  }
  $wtotal = $wup + $wdown + $wzero
  $score = 0.0; $breadth = 0.0
  if ($wtotal -gt 0) { $score = ($wup - $wdown) / $wtotal; $breadth = $wup / $wtotal }
  $freshShare = 0.0
  if ($rows.Count -gt 0) { $freshShare = $freshN / $rows.Count }
  $raw = 'stable'
  if ($voters -lt 2 -or $freshShare -lt 0.6) { $raw = 'insufficient-data' }
  elseif ($score -ge 0.5 -and $breadth -ge 0.7) { $raw = 'escalating' }   # supermajority clause
  elseif ($score -ge 0.25) { $raw = 'tightening' }
  elseif ($score -le -0.25) { $raw = 'easing' }
  return [pscustomobject]@{
    raw = $raw; score = [math]::Round([double]$score, 3); breadth = [math]::Round([double]$breadth, 3)
    wup = [double]$wup; wdown = [double]$wdown; wzero = [double]$wzero; wtotal = [double]$wtotal
    voters = [int]$voters; freshShare = [math]::Round([double]$freshShare, 2)
  }
}

function Resolve-CmdHysteresis {
  # $PriorRows: this unit's state-log rows {month, published_state, candidate_state,
  # candidate_streak} (any order). $Month 'yyyy-MM'. $Raw = this month's raw state.
  # Returns {published, candidate, streak, action}.
  param([object[]]$PriorRows, [string]$Month, [string]$Raw)
  $hist = @($PriorRows | Sort-Object month)
  foreach ($h in $hist) {
    if ([string]$h.month -eq $Month) {
      # same-month rebuild NEVER flips (raw drift from source revisions is ignored)
      return [pscustomobject]@{ published = [string]$h.published_state; candidate = [string]$h.candidate_state
                                streak = [int]$h.candidate_streak; action = 'same-month-noop' }
    }
  }
  if (@($hist).Count -eq 0) {
    return [pscustomobject]@{ published = $Raw; candidate = ''; streak = 0; action = 'initial' }
  }
  if ($Raw -eq 'insufficient-data') {
    # availability fact: bypass hysteresis, candidate machinery cleared
    return [pscustomobject]@{ published = 'insufficient-data'; candidate = ''; streak = 0; action = 'availability' }
  }
  $last = $hist[@($hist).Count - 1]
  $basePub = ''
  for ($i = @($hist).Count - 1; $i -ge 0; $i--) {
    if ([string]$hist[$i].published_state -ne 'insufficient-data') { $basePub = [string]$hist[$i].published_state; break }
  }
  if ($basePub -eq '') {
    # log holds only availability rows: first real read
    return [pscustomobject]@{ published = $Raw; candidate = ''; streak = 0; action = 'initial' }
  }
  if ($Raw -eq $basePub) {
    return [pscustomobject]@{ published = $basePub; candidate = ''; streak = 0; action = 'hold' }
  }
  $lastCand = [string]$last.candidate_state
  $lastStreak = [int]$last.candidate_streak
  if ($lastCand -eq $Raw) {
    $newStreak = $lastStreak + 1
    if ($newStreak -ge 2) {
      return [pscustomobject]@{ published = $Raw; candidate = ''; streak = 0; action = 'flip' }
    }
    return [pscustomobject]@{ published = $basePub; candidate = $Raw; streak = $newStreak; action = 'streak' }
  }
  return [pscustomobject]@{ published = $basePub; candidate = $Raw; streak = 1; action = 'candidate' }
}

function Get-CmdDiverging {
  # input-cost transmission read (v7 segments): ANY input/energy layer (S1, S4) under
  # pressure while ALL product layers (S2 raw crops, S3 processed) hold.
  param([string[]]$InputStates, [string[]]$ProductStates)
  $hot = @('tightening', 'escalating')
  $calm = @('stable', 'easing')
  $anyInputHot = @($InputStates | Where-Object { $hot -contains $_ }).Count -gt 0
  $prod = @($ProductStates)
  $allProductsCalm = ($prod.Count -gt 0) -and (@($prod | Where-Object { $calm -contains $_ }).Count -eq $prod.Count)
  return ([bool]($anyInputHot -and $allProductsCalm))
}

function Get-CmdConfidence {
  param([int]$Voters, [string[]]$StaleNames, [double]$FreshShare)
  $parts = New-Object System.Collections.Generic.List[string]
  if ([int]$Voters -lt 5) { $parts.Add(("rests on {0} series" -f [int]$Voters)) }
  if (@($StaleNames).Count -gt 0) { $parts.Add(("stale and not voting: {0}" -f (@($StaleNames) -join ', '))) }
  if ($parts.Count -eq 0) { return ("broad base: {0} series voting, {1:P0} fresh" -f [int]$Voters, [double]$FreshShare) }
  return ($parts -join '; ')
}

function Test-CmdBannedLanguage {
  # TRUE = text violates (dramatic term or causal phrasing). Gates fail on TRUE.
  param([string]$Text)
  $low = ([string]$Text).ToLowerInvariant()
  foreach ($w in $CMD_BANNED_TERMS) { if ($low.Contains($w)) { return $true } }
  return [bool]([regex]::IsMatch($low, $CMD_CAUSAL_REGEX, 'IgnoreCase'))
}
