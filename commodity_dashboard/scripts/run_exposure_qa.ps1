# run_exposure_qa.ps1 — M11 rendered-DOM + screenshots gate for commodity_exposure.html.
# Drives headless Chrome/Edge: the ?qa=1 self-report verifies every card's chart draws under ALL FOUR
# lenses (event/ytd/yoy/3m) via toDataURL, plus 0 console errors, a banned-words DOM scan, no empty
# stat strips, the footer build status, and that the empty analysis slots are present. Then archives
# one tall screenshot per lens (each capturing all five segments). Timer-based draws in the page mean
# headless --dump-dom captures the report (the rAF->setTimeout lesson). Exit 0 PASS / 1 FAIL. PS 5.1.
param([string]$IndexPath = '')

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
if ($IndexPath -eq '') { $IndexPath = Join-Path $base 'dashboard\commodity_exposure.html' }
if (-not (Test-Path $IndexPath)) { Write-Host 'FAIL: commodity_exposure.html missing'; exit 1 }
$shotDir = Join-Path $base 'logs\exposure_qa'
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
  $quoted = @($BrowserArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
  return (cmd /c ('"' + $browser + '" ' + $quoted + ' 2>nul'))
}

# ---- 1. ?qa=1 self-report (retry/poll until present; page draws via setTimeout) ----
$domFile = Join-Path $shotDir ("qa_dom_{0}.html" -f $stamp)
$got = $false; $reportTxt = $null; $verdict = $null
for ($a = 1; $a -le 5; $a++) {
  Invoke-Headless @('--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=30000', '--dump-dom', ($fileUrl + '?qa=1')) | Set-Content -Path $domFile -Encoding UTF8
  $dom = Get-Content $domFile -Raw -Encoding UTF8
  if (-not [string]::IsNullOrWhiteSpace($dom)) {
    $tm = [regex]::Match($dom, '<title>(QA:[A-Z]+)</title>')
    $rm = [regex]::Match($dom, '(?s)<pre id="qa-results">(.+?)</pre>')
    if ($tm.Success -and $rm.Success -and $rm.Groups[1].Value.Trim().Length -gt 2) {
      $verdict = $tm.Groups[1].Value; $reportTxt = [System.Net.WebUtility]::HtmlDecode($rm.Groups[1].Value); $got = $true
      Write-Host ("QA self-report captured on attempt {0}/5" -f $a); break
    }
  }
  Write-Host ("attempt {0}/5: QA self-report not yet in dumped DOM; retrying" -f $a); Start-Sleep -Seconds 2
}
if (-not $got) { Write-Host 'RESULT: FAIL (QA report not present in rendered DOM after 5 attempts)'; exit 1 }
Write-Host '--- in-page QA report ---'; Write-Host $reportTxt
try {
  $rep = $reportTxt | ConvertFrom-Json
  if ([int]$rep.canvases_total -le 0) { $fails.Add('zero canvases rendered') }
  if ([int]$rep.canvases_drawn -ne [int]$rep.canvases_total) { $fails.Add(("canvases drawn {0}/{1} across the four lenses" -f $rep.canvases_drawn, $rep.canvases_total)) }
  if (@($rep.console_errors).Count -gt 0) { $fails.Add('console errors: ' + (@($rep.console_errors) -join ' | ')) }
  if (@($rep.banned_hits).Count -gt 0) { $fails.Add('banned words in DOM: ' + (@($rep.banned_hits) -join ', ')) }
  if ([int]$rep.empty_summaries -gt 0) { $fails.Add(("{0} empty stat strips" -f $rep.empty_summaries)) }
  if ([string]$rep.footer_status -eq 'MISSING') { $fails.Add('footer manifest status missing') }
  if ([int]$rep.analysis_slots -le 0) { $fails.Add('no analysis slots present') }
} catch { $fails.Add('QA report unparseable: ' + $_.Exception.Message) }
if ($verdict -ne 'QA:PASS') { $fails.Add(("in-page verdict {0}" -f $verdict)) }

# ---- 2. one tall screenshot per lens (each captures all five segments) ----
foreach ($L in @('event', 'ytd', 'yoy', '3m')) {
  $shot = Join-Path $shotDir ("exposure_{0}_{1}.png" -f $L, $stamp)
  Invoke-Headless @('--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=12000', '--hide-scrollbars', '--window-size=1600,3200', ('--screenshot=' + $shot), ($fileUrl + '?lens=' + $L)) | Out-Null
  if (-not (Test-Path $shot) -or (Get-Item $shot).Length -lt 20000) { $fails.Add('screenshot missing/blank: ' + (Split-Path -Leaf $shot)) }
  else { Write-Host ("screenshot archived: {0} ({1} KB)" -f (Split-Path -Leaf $shot), [int]((Get-Item $shot).Length / 1KB)) }
}

# ---- 3. offline integrity: the page must reference 0 external resources (same bar as the prior index.html) ----
$pageText = Get-Content $IndexPath -Raw -Encoding UTF8
$ext = [regex]::Matches($pageText, '(?i)(src|href)\s*=\s*"https?://[^"]*"')
if ($ext.Count -gt 0) { foreach ($m in $ext) { $fails.Add('external resource ref: ' + $m.Value) }; Write-Host ("external resource refs: {0} (must be 0)" -f $ext.Count) }
else { Write-Host 'external resources: 0 (fully self-contained)' }

if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (exposure rendered-DOM QA across 4 lenses + 0 external resources + screenshots)'; exit 0
