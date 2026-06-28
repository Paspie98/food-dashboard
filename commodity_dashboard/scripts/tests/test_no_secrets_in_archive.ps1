# test_no_secrets_in_archive.ps1 — Mission 5/8 fatal gate (key-leak defence).
# Scans the DATA + ARCHIVE roots (not source scripts) for: (a) the literal values of
# FRED_API_KEY / USDA_FAS_KEY if present in env/.env, (b) a key-bearing FRED request URL
# (api_key= followed by anything other than the {KEY} placeholder), (c) generic secret
# shapes. FRED embeds the key in the query string, so an archived request URL is the one
# way a key leaks despite the response-body scan. Filenames are reported; secret VALUES
# are never printed. Exit 0 PASS / 1 FAIL. PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'parse_helpers.ps1')

$roots = @('raw_archive', 'logs', 'cleaned_data', 'dashboard') | ForEach-Object { Join-Path $base $_ }
$textExt = @('.json', '.csv', '.js', '.html', '.txt', '.md', '.xml')   # scan text artifacts; skip binaries (xlsx/png/zip)
$fails = New-Object System.Collections.Generic.List[string]

# literal key values (no printing) — read EVERY key dynamically so the scan can never go
# stale when a new keyed family is added (the EIA-key-missed-from-this-list lesson).
$keyValues = @()
$envp = Join-Path $base '.env'
if (Test-Path $envp) {
  foreach ($line in (Get-Content $envp)) {
    $kv = $line -split '=', 2
    if ($kv.Count -eq 2 -and $kv[0].Trim() -match '^[A-Za-z0-9_]+$') {
      $val = $kv[1].Trim().Trim('"')
      if ($val.Length -ge 12) { $keyValues += $val }   # ignore short/non-secret values
    }
  }
}
foreach ($name in @('FRED_API_KEY', 'EIA_API_KEY', 'USDA_FAS_KEY')) {   # CI env fallback (.env absent in CI)
  $v = [Environment]::GetEnvironmentVariable($name)
  if (-not [string]::IsNullOrWhiteSpace($v)) { $keyValues += $v.Trim() }
}
$keyValues = @($keyValues | Select-Object -Unique)
Write-Host ("literal key values available to scan for: {0} (dynamic from .env + CI env)" -f $keyValues.Count)

$urlPattern = 'api_key=(?!\{KEY\})[A-Za-z0-9]{8,}'
$genericPatterns = @('\bAKIA[0-9A-Z]{16}\b', 'Bearer\s+[A-Za-z0-9\-_\.]{20,}')

$scanned = 0
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  foreach ($f in (Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue)) {
    if ($textExt -notcontains $f.Extension.ToLowerInvariant()) { continue }
    $scanned++
    # (a) literal key values
    foreach ($kv in $keyValues) {
      if (Select-String -Path $f.FullName -SimpleMatch -Pattern $kv -Quiet -ErrorAction SilentlyContinue) {
        $fails.Add(("LITERAL KEY VALUE in {0}" -f $f.FullName.Substring($base.Length + 1)))
      }
    }
    # (b) key-bearing request URL + (c) generic shapes
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { continue }
    if ([regex]::IsMatch($content, $urlPattern)) {
      $fails.Add(("KEY-BEARING URL (api_key=...) in {0}" -f $f.FullName.Substring($base.Length + 1)))
    }
    foreach ($gp in $genericPatterns) {
      if ([regex]::IsMatch($content, $gp)) { $fails.Add(("secret-shaped token ({0}) in {1}" -f $gp, $f.FullName.Substring($base.Length + 1))) }
    }
  }
}

Write-Host ("scanned {0} text artifacts under: {1}" -f $scanned, ((@('raw_archive', 'logs', 'cleaned_data', 'dashboard')) -join ', '))
if ($fails.Count -gt 0) {
  Write-Host ("RESULT: FAIL ({0}) - secrets present in committable artifacts:" -f $fails.Count)
  foreach ($f in $fails) { Write-Host (' - ' + $f) }
  exit 1
}
Write-Host 'RESULT: PASS (no key values or key-bearing URLs in archive/data/dashboard artifacts)'
exit 0
