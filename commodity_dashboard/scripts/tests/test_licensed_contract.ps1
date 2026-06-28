# test_licensed_contract.ps1 — Mission 5 fatal gate (lane contract, spec B6).
# Structural REJECTION fixtures for ingest_licensed_uploads.ps1 via the test-only
# CMD_INBOX_DIR override. Fixture workbooks exist only in a scratch dir, are always
# rejected, and never touch history (hash-proven) — nothing synthetic can enter the
# pipeline. The acceptance path remains owed to the first REAL workbook (never
# fabricated). Exit 0 PASS / 1 FAIL.

$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $testDir
$base = Split-Path -Parent $scriptsDir
$ingest = Join-Path $scriptsDir 'ingest_licensed_uploads.ps1'
$historyPath = Join-Path $base 'cleaned_data\commodity_series_history.csv'
$fails = New-Object System.Collections.Generic.List[string]

# mini-xlsx writer lives in mini_xlsx_helper.ps1 (shared test-only helper)
. (Join-Path $testDir 'mini_xlsx_helper.ps1')

# scratch registries (the production registry has zero licensed rows from v8 on, so an
# ACTIVE scratch registry is needed to keep exercising the contract-validation logic;
# the DORMANT one verifies the fail-closed guard).
$actRegDir = Join-Path $env:TEMP ('cmd_lane_reg_act_' + (Get-Random))
$dorRegDir = Join-Path $env:TEMP ('cmd_lane_reg_dor_' + (Get-Random))
New-Item -ItemType Directory -Force -Path $actRegDir, $dorRegDir | Out-Null
Set-Content -Path (Join-Path $actRegDir 'commodity_registry_v1_active.csv') -Encoding UTF8 -Value @(
  'row_id,commodity,access,inbox_pattern',
  'CO-003,cocoa,licensed-upload,bloomberg_weekly_*.xlsx#settlements#LCOA1')
Set-Content -Path (Join-Path $dorRegDir 'commodity_registry_v1_active.csv') -Encoding UTF8 -Value @(
  'row_id,commodity,access,inbox_pattern',
  'CO-001,cocoa,open,')

function Invoke-RejectionCase {
  param([string]$CaseName, [scriptblock]$MakeWorkbook, [string]$ExpectSnippet, [string]$RegDir = $actRegDir)
  $scratch = Join-Path $env:TEMP ('cmd_lane_fix_' + (Get-Random))
  New-Item -ItemType Directory -Force -Path $scratch | Out-Null
  try {
    & $MakeWorkbook (Join-Path $scratch 'bloomberg_weekly_2026-06-12.xlsx')
    $hashBefore = ''
    if (Test-Path $historyPath) { $hashBefore = (Get-FileHash $historyPath -Algorithm SHA256).Hash }
    $env:CMD_INBOX_DIR = $scratch
    $env:CMD_REGISTRY_DIR = $RegDir
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ingest 2>&1 | Out-String
    $code = $LASTEXITCODE
    $env:CMD_INBOX_DIR = $null; $env:CMD_REGISTRY_DIR = $null
    $hashAfter = ''
    if (Test-Path $historyPath) { $hashAfter = (Get-FileHash $historyPath -Algorithm SHA256).Hash }
    if ($code -ne 1) { $script:fails.Add(("{0}: expected exit 1 (reject), got {1}" -f $CaseName, $code)) }
    if ($output -notmatch 'REJECTED') { $script:fails.Add(("{0}: output lacks REJECTED banner" -f $CaseName)) }
    if ($ExpectSnippet -ne '' -and $output -notmatch [regex]::Escape($ExpectSnippet)) { $script:fails.Add(("{0}: violation message lacks '{1}'" -f $CaseName, $ExpectSnippet)) }
    if ($hashBefore -ne $hashAfter) { $script:fails.Add(("{0}: HISTORY MUTATED by a rejected workbook (never-partial-ingest violated)" -f $CaseName)) }
    if ($script:fails.Count -eq 0 -or -not ($script:fails[$script:fails.Count - 1] -like ($CaseName + '*'))) { Write-Host ("{0}: rejected cleanly, history untouched" -f $CaseName) }
  } finally {
    $env:CMD_INBOX_DIR = $null; $env:CMD_REGISTRY_DIR = $null
    Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
  }
}

# active-lane validation cases (scratch registry has one licensed row, ticker LCOA1)
Invoke-RejectionCase 'case-corrupt-file' { param($p) Set-Content -Path $p -Value 'not an xlsx' -Encoding ASCII } 'unreadable as xlsx'
Invoke-RejectionCase 'case-wrong-columns' { param($p) New-MiniXlsx -Path $p -SheetName 'settlements' -Rows @(
  @('ticker', 'date', 'price'),
  @('LCOA1', '2026-06-05', '6000')
) } 'required column missing'
Invoke-RejectionCase 'case-missing-tickers' { param($p) New-MiniXlsx -Path $p -SheetName 'settlements' -Rows @(
  @('ticker', 'date', 'settle', 'currency', 'unit'),
  @('CC1', '2026-06-05', '6000', 'USD', 'USD/t')
) } 'registry tickers absent'
Invoke-RejectionCase 'case-wrong-sheet' { param($p) New-MiniXlsx -Path $p -SheetName 'prices' -Rows @(
  @('ticker', 'date', 'settle', 'currency', 'unit')
) } "sheet 'settlements' missing"
# dormant-lane case: production reality from v8 (zero licensed rows) -> any workbook rejected fail-closed
Invoke-RejectionCase 'case-dormant-lane' { param($p) New-MiniXlsx -Path $p -SheetName 'settlements' -Rows @(
  @('ticker', 'date', 'settle', 'currency', 'unit'),
  @('LCOA1', '2026-06-05', '6000', 'USD', 'USD/t')
) } 'lane dormant' $dorRegDir

Remove-Item -Recurse -Force $actRegDir, $dorRegDir -ErrorAction SilentlyContinue
if ($fails.Count -gt 0) { Write-Host ("RESULT: FAIL ({0})" -f $fails.Count); foreach ($f in $fails) { Write-Host (' - ' + $f) }; exit 1 }
Write-Host 'RESULT: PASS (licensed lane contract fixtures - dormant fail-closed + active-lane rejection classes, history never mutated)'; exit 0
