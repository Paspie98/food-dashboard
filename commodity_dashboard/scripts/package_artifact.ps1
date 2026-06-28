# package_artifact.ps1 — Mission 8 offline artifact (consumer Phase B8 pattern).
# 1) verify N/N dashboard files match the manifest's SHA-256 list (fail on any mismatch),
# 2) zip the dashboard (incl. manifest files) to logs/artifact/,
# 3) extract to a scratch dir and run the FULL browser DOM QA against the extracted copy
#    (the artifact itself, not the source tree). Exit 0 PASS / 1 FAIL. PS 5.1.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
$dashDir = Join-Path $base 'dashboard'
$artDir = Join-Path $base 'logs\artifact'
New-Item -ItemType Directory -Force -Path $artDir | Out-Null
$stamp = [datetime]::UtcNow.ToString('yyyyMMdd_HHmmss')

# ---- 1. N/N hash verification against the manifest ----
$manifest = Get-Content (Join-Path $dashDir 'build_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$manifest.BUILD_STATUS -ne 'PASS') { Write-Host ("FAIL: manifest BUILD_STATUS={0} - refusing to package a failing build" -f $manifest.BUILD_STATUS); exit 1 }
$expected = $manifest.artifact_hashes_sha256
$n = 0; $ok = 0
foreach ($p in $expected.PSObject.Properties) {
  $n++
  $f = Join-Path $dashDir $p.Name
  if (-not (Test-Path $f)) { Write-Host ("FAIL: manifest-listed file missing: {0}" -f $p.Name); exit 1 }
  $h = (Get-FileHash $f -Algorithm SHA256).Hash
  if ($h -eq [string]$p.Value) { $ok++ } else { Write-Host ("FAIL: hash mismatch {0}" -f $p.Name); exit 1 }
}
Write-Host ("hash verification: {0}/{1} manifest hashes match" -f $ok, $n)

# ---- 2. package ----
$zipPath = Join-Path $artDir ("commodity_dashboard_offline_{0}.zip" -f $stamp)
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
[System.IO.Compression.ZipFile]::CreateFromDirectory($dashDir, $zipPath)
Write-Host ("packaged: {0} ({1} KB)" -f (Split-Path -Leaf $zipPath), [int]((Get-Item $zipPath).Length / 1KB))

# ---- 3. offline DOM QA on the EXTRACTED ARTIFACT itself ----
$scratch = Join-Path $env:TEMP ('cmd_artifact_qa_' + (Get-Random))
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $scratch)
try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'run_exposure_qa.ps1') -IndexPath (Join-Path $scratch 'commodity_exposure.html')
  $qa = $LASTEXITCODE
} finally {
  Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
}
if ($qa -ne 0) { Write-Host 'FAIL: browser QA on the extracted artifact failed'; exit 1 }
Write-Host 'RESULT: PASS (artifact hash-verified, packaged, and DOM-QA-passed offline)'
exit 0
