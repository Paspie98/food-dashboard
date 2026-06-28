# test_banned_words.ps1 — Mission 5 fatal gate (Principle 4, consumer pattern).
# 1) POSITIVE fixture: detector must flag a deliberately dramatic text (proves the
#    detector works — a silent detector is worse than none).
# 2) NEGATIVE fixture: neutral %-and-window phrasing must produce zero hits.
# 3) LIVE scan: every emitted dashboard text artifact must contain zero banned terms.
# Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$fails = New-Object System.Collections.Generic.List[string]

$banned = @('worst since', 'soar', 'skyrocket', 'collapse', 'crisis', 'super el nino',
            'perfect storm', 'unprecedented', 'plunge', 'explode')

function Find-BannedHits([string]$text) {
  $hits = New-Object System.Collections.Generic.List[string]
  $low = $text.ToLowerInvariant()
  foreach ($w in $banned) { if ($low.Contains($w)) { $hits.Add($w) } }
  return ,$hits
}

# --- 1. positive fixture ---
$positive = 'Cocoa prices soar in a perfect storm; the worst since 1977 as markets collapse amid an unprecedented crisis.'
$posHits = Find-BannedHits $positive
if (@($posHits).Count -lt 5) { $fails.Add(("positive fixture: detector found only {0} of >=5 planted terms - detector broken" -f @($posHits).Count)) }
else { Write-Host ("positive fixture: detector flagged {0} planted terms (detector alive)" -f @($posHits).Count) }

# --- 2. negative fixture ---
$negative = 'EU butter averaged 404.84 EUR/100kg in the week to 2026-06-07, down 2.1% over 13 weeks; urea rose 8.4 index points over the 3 months to May 2026.'
$negHits = Find-BannedHits $negative
if (@($negHits).Count -gt 0) { $fails.Add(('negative fixture: false positives: ' + ($negHits -join ', '))) }
else { Write-Host 'negative fixture: 0 hits (no false positives)' }

# --- 3. live scan over emitted artifacts ---
$targets = @('dashboard\data.js', 'dashboard\display_contract.js', 'dashboard\synthesis.js', 'dashboard\index.html', 'dashboard\commodity_exposure.html')
$mandatory = @('dashboard\data.js', 'dashboard\display_contract.js')
foreach ($t in $targets) {
  $p = Join-Path $base $t
  if (-not (Test-Path $p)) {
    if ($mandatory -contains $t) { $fails.Add("live scan: mandatory artifact missing: $t") }
    else { Write-Host ("live scan: {0} not yet built (skipped)" -f $t) }
    continue
  }
  $hits = Find-BannedHits (Get-Content $p -Raw -Encoding UTF8)
  if (@($hits).Count -gt 0) { $fails.Add(("live scan: {0} contains banned terms: {1}" -f $t, ($hits -join ', '))) }
  else { Write-Host ("live scan: {0} clean" -f $t) }
}

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (banned words)'; exit 0
