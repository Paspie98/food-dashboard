# run_browser_qa.ps1 — Mission 6 browser QA on the RENDERED DOM (not function level).
# Drives headless Chrome/Edge: ?qa=1 self-check report (canvas draws via toDataURL,
# console errors, banned-words DOM scan, summary lines, footer status), plus archived
# screenshots of both views. Exit 0 PASS / 1 FAIL. PS 5.1 compatible.

param([string]$IndexPath = '')

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
if ($IndexPath -eq '') { $IndexPath = Join-Path $base 'dashboard\index.html' }
if (-not (Test-Path $IndexPath)) { Write-Host 'FAIL: index.html missing'; exit 1 }
$shotDir = Join-Path $base 'logs\qa_screenshots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null
$stamp = [datetime]::UtcNow.ToString('yyyyMMdd_HHmmss')

$browser = $null
foreach ($cand in @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")) {
  if (Test-Path $cand) { $browser = $cand; break }
}
if ($null -eq $browser) { Write-Host 'FAIL: no Chromium browser found for headless QA'; exit 1 }
Write-Host ("browser: {0}" -f $browser)

$fileUrl = 'file:///' + ($IndexPath -replace '\\', '/')
$fails = New-Object System.Collections.Generic.List[string]

function Invoke-Headless([string[]]$BrowserArgs) {
  # PS 5.1 wraps native stderr lines in ErrorRecords (NativeCommandError) — Chrome emits
  # harmless stderr noise, so stderr is dropped at the cmd level, never in PowerShell.
  $quoted = @($BrowserArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
  return (cmd /c ('"' + $browser + '" ' + $quoted + ' 2>nul'))
}

# ---- 1. QA-mode DOM dump (retry/poll) ----
# The in-page ?qa=1 self-report (#qa-results + a "QA:" <title>) is populated only after the
# canvases draw on rAF + a settle timeout; headless --dump-dom on a cold/heavier runner can
# capture before it fires (flaky in CI — observed on the EIA-fresh run). Poll: re-dump up to
# 5x with a large virtual-time budget until the report actually has content, then parse it.
$domFile = Join-Path $shotDir ("qa_dom_{0}.html" -f $stamp)
$titleM = $null; $reportM = $null; $got = $false
for ($attempt = 1; $attempt -le 5; $attempt++) {
  Invoke-Headless @('--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=30000', '--dump-dom', ($fileUrl + '?qa=1')) | Set-Content -Path $domFile -Encoding UTF8
  $dom = Get-Content $domFile -Raw -Encoding UTF8
  if (-not [string]::IsNullOrWhiteSpace($dom)) {
    $tm = [regex]::Match($dom, '<title>(QA:[A-Z]+)</title>')
    $rm = [regex]::Match($dom, '(?s)<pre id="qa-results">(.+?)</pre>')
    if ($tm.Success -and $rm.Success -and $rm.Groups[1].Value.Trim().Length -gt 2) { $titleM = $tm; $reportM = $rm; $got = $true; Write-Host ("QA self-report captured on attempt {0}/5" -f $attempt); break }
  }
  Write-Host ("attempt {0}/5: QA self-report not yet in dumped DOM; retrying" -f $attempt)
  Start-Sleep -Seconds 2
}
if (-not $got) { $fails.Add('QA report not present in rendered DOM after 5 attempts') }
else {
  $verdict = $titleM.Groups[1].Value
  $reportTxt = [System.Net.WebUtility]::HtmlDecode($reportM.Groups[1].Value)
  Write-Host '--- in-page QA report ---'
  Write-Host $reportTxt
  try {
    $rep = $reportTxt | ConvertFrom-Json
    if ([int]$rep.canvases_total -le 0) { $fails.Add('zero canvases rendered') }
    if ([int]$rep.canvases_drawn -ne [int]$rep.canvases_total) { $fails.Add(("canvases drawn {0}/{1}" -f $rep.canvases_drawn, $rep.canvases_total)) }
    if (@($rep.console_errors).Count -gt 0) { $fails.Add(('console errors: ' + (@($rep.console_errors) -join ' | '))) }
    if (@($rep.banned_hits).Count -gt 0) { $fails.Add(('banned words in DOM: ' + (@($rep.banned_hits) -join ', '))) }
    if ([int]$rep.empty_summaries -gt 0) { $fails.Add(("{0} empty summary lines" -f $rep.empty_summaries)) }
    if ([string]$rep.footer_status -eq 'MISSING') { $fails.Add('footer manifest status missing') }
  } catch { $fails.Add(('QA report unparseable: ' + $_.Exception.Message)) }
  if ($verdict -ne 'QA:PASS') { $fails.Add(("in-page verdict {0}" -f $verdict)) }
}

# ---- 2. screenshots (both views) ----
$shotA = Join-Path $shotDir ("dashboard_layers_{0}.png" -f $stamp)
$shotB = Join-Path $shotDir ("dashboard_groups_{0}.png" -f $stamp)
Invoke-Headless @('--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=10000', '--window-size=1500,2600', ('--screenshot=' + $shotA), $fileUrl) | Out-Null
Invoke-Headless @('--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=10000', '--window-size=1500,2600', ('--screenshot=' + $shotB), ($fileUrl + '?view=groups')) | Out-Null
foreach ($s in @($shotA, $shotB)) {
  if (-not (Test-Path $s) -or (Get-Item $s).Length -lt 20000) { $fails.Add(('screenshot missing/blank: ' + (Split-Path -Leaf $s))) }
  else { Write-Host ("screenshot archived: {0} ({1} KB)" -f (Split-Path -Leaf $s), [int]((Get-Item $s).Length / 1KB)) }
}

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (browser QA on rendered DOM)'; exit 0
