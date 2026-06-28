# ingest_licensed_uploads.ps1 — Mission 3 licensed lane (spec: docs/capture_spec.md B6).
# Reads the NEWEST bloomberg_weekly_YYYY-MM-DD.xlsx from uploads_inbox/, validates the
# whole workbook against the contract, and only then merges. ANY violation rejects the
# whole workbook (no partial ingest). Never fetches anything; never writes to the inbox.
# PS 5.1 compatible.

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'xlsx_helpers.ps1')
. (Join-Path $scriptDir 'parse_helpers.ps1')

$inbox = Join-Path $base 'uploads_inbox'
# test-only override (consumer V3_CLEANED_DIR pattern): lets fixture tests exercise the
# validation paths against a scratch inbox without touching the real user-only surface
$inboxOverride = [string][Environment]::GetEnvironmentVariable('CMD_INBOX_DIR')
if (-not [string]::IsNullOrWhiteSpace($inboxOverride)) { $inbox = $inboxOverride }
$cleanedDir = Join-Path $base 'cleaned_data'
$logsDir = Join-Path $base 'logs'
$uploadsArchive = Join-Path $base 'raw_archive\uploads'
New-Item -ItemType Directory -Force -Path $cleanedDir, $logsDir, $uploadsArchive | Out-Null
$historyPath = Join-Path $cleanedDir 'commodity_series_history.csv'
$captureLogPath = Join-Path $logsDir 'capture_all_log.csv'
$runStampUtc = [datetime]::UtcNow

$wb = Get-ChildItem -Path $inbox -Filter 'bloomberg_weekly_*.xlsx' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^bloomberg_weekly_\d{4}-\d{2}-\d{2}\.xlsx$' } |
  Sort-Object Name -Descending | Select-Object -First 1
if ($null -eq $wb) {
  Write-Host 'no workbook matching bloomberg_weekly_YYYY-MM-DD.xlsx in uploads_inbox/ - nothing ingested (lane idle)'
  exit 0
}
Write-Host ("validating workbook: {0}" -f $wb.Name)

$regDir = Join-Path $base 'registry'
# test-only override (fixtures point at a scratch registry to exercise active-lane validation)
$regDirOverride = [string][Environment]::GetEnvironmentVariable('CMD_REGISTRY_DIR')
if (-not [string]::IsNullOrWhiteSpace($regDirOverride)) { $regDir = $regDirOverride }
$regFile = Get-NewestRegistry $regDir
$licRows = @(Import-Csv $regFile.FullName | Where-Object { $_.access -eq 'licensed-upload' })

# fail-closed: when the lane is dormant (no licensed-upload rows, e.g. v8 onward), an
# uploaded workbook is unexpected and is REJECTED rather than silently no-op-accepted.
if (@($licRows).Count -eq 0) {
  Write-Host ("REJECTED: licensed lane dormant (no licensed-upload rows in {0}); workbook {1} not ingested." -f $regFile.Name, $wb.Name)
  exit 1
}

$violations = New-Object System.Collections.Generic.List[string]

$sheetNames = @()
try { $sheetNames = Get-XlsxSheetNames -Path $wb.FullName } catch { $violations.Add(('workbook unreadable as xlsx: ' + $_.Exception.Message)) }
if ($violations.Count -eq 0 -and $sheetNames -notcontains 'settlements') {
  $violations.Add(("sheet 'settlements' missing; sheets present: " + ($sheetNames -join ', ')))
} elseif ($violations.Count -eq 0) {
  $sheet = Read-XlsxSheet -Path $wb.FullName -SheetName 'settlements'
  # NOTE: bare @() over a List[object] of Hashtables throws ArgumentException in PS 5.1
  # (reproduced 2026-06-12); use the List's own Count, explicitly cast.
  if ([int]$sheet.Count -lt 2) { $violations.Add('settlements sheet has no data rows') }
  else {
    # header row 1: exact column set ticker,date,settle,currency,unit (any order)
    $hdrCells = $sheet[0].Cells
    $colOf = @{}
    foreach ($k in $hdrCells.Keys) { $colOf[([string]$hdrCells[$k]).Trim().ToLowerInvariant()] = [int]$k }
    $required = @('ticker', 'date', 'settle', 'currency', 'unit')
    foreach ($req in $required) { if (-not $colOf.ContainsKey($req)) { $violations.Add("required column missing: $req") } }
    $extra = @($colOf.Keys | Where-Object { $required -notcontains $_ })
    if (@($extra).Count -gt 0) { $violations.Add(('unexpected columns: ' + ($extra -join ', '))) }

    $byTicker = @{}
    if ($violations.Count -eq 0) {
      $inv = [System.Globalization.CultureInfo]::InvariantCulture
      for ($i = 1; $i -lt [int]$sheet.Count; $i++) {
        $cells = $sheet[$i].Cells
        $rowNo = [int]$sheet[$i].RowIndex
        $get = { param($name) $c = $colOf[$name]; if ($cells.ContainsKey($c)) { [string]$cells[$c] } else { '' } }
        $ticker = (& $get 'ticker').Trim()
        $dateS = (& $get 'date').Trim()
        $settleS = (& $get 'settle').Trim()
        if ($ticker -eq '' -and $dateS -eq '' -and $settleS -eq '') { continue }   # fully blank row tolerated
        if ($ticker -eq '') { $violations.Add("row ${rowNo}: empty ticker"); continue }
        $dt = [datetime]::MinValue
        $isIso = [datetime]::TryParseExact($dateS, 'yyyy-MM-dd', $inv, [System.Globalization.DateTimeStyles]::None, [ref]$dt)
        if (-not $isIso) {
          # Excel date serial tolerated (Excel stores dates numerically) — converted, never guessed
          $serial = Parse-PriceLoose $dateS
          if ($null -ne $serial -and [double]$serial -gt 20000 -and [double]$serial -lt 80000) { $dt = [datetime]::FromOADate([double]$serial); $isIso = $true }
        }
        if (-not $isIso) { $violations.Add("row ${rowNo}: date not ISO yyyy-mm-dd: '$dateS'"); continue }
        $v = Parse-PriceLoose $settleS
        if ($null -eq $v) { $violations.Add("row ${rowNo}: settle not castable: '$settleS'"); continue }
        $key = $dt.ToString('yyyy-MM-dd')
        if (-not $byTicker.ContainsKey($ticker)) { $byTicker[$ticker] = @{} }
        if ($byTicker[$ticker].ContainsKey($key)) {
          if ([double]$byTicker[$ticker][$key] -ne [double]$v) { $violations.Add("row ${rowNo}: conflicting settle for $ticker on $key") }
        } else { $byTicker[$ticker][$key] = [double]$v }
      }

      # every registry licensed ticker must be present (first-upload reconciliation is explicit)
      $regTickers = @($licRows | ForEach-Object { (([string]$_.inbox_pattern) -split '#')[2] })
      $missing = @($regTickers | Where-Object { -not $byTicker.ContainsKey($_) })
      if (@($missing).Count -gt 0) {
        $violations.Add(('registry tickers absent from workbook: ' + ($missing -join ', ') +
          ' | workbook tickers: ' + (($byTicker.Keys | Sort-Object) -join ', ') +
          ' | if the workbook tickers are the real ones, correct the registry in a new version - never ingest on mismatch'))
      }
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host ("REJECTED: workbook {0} violates the lane contract ({1} violations) - nothing ingested:" -f $wb.Name, $violations.Count)
  foreach ($v in $violations) { Write-Host ("  - " + $v) }
  exit 1
}

# ---------- accepted: archive + merge ----------
$archName = ($runStampUtc.ToString('yyyyMMdd_HHmmss') + '_' + $wb.Name)
Copy-Item $wb.FullName (Join-Path $uploadsArchive $archName)

$history = @{}
if (Test-Path $historyPath) {
  foreach ($h in (Import-Csv $historyPath)) {
    if (-not $history.ContainsKey($h.row_id)) { $history[$h.row_id] = New-Object System.Collections.Generic.List[object] }
    $history[$h.row_id].Add(@{ date = [string]$h.date; value = [double]$h.value })
  }
}

$logRows = New-Object System.Collections.Generic.List[object]
foreach ($r in $licRows) {
  $ticker = (([string]$r.inbox_pattern) -split '#')[2]
  $map = $byTicker[$ticker]
  $obs = New-Object System.Collections.Generic.List[object]
  foreach ($k in ($map.Keys | Sort-Object)) { $obs.Add(@{ date = [string]$k; value = [double]$map[$k] }) }
  $history[$r.row_id] = $obs
  $logRows.Add([pscustomobject]@{
    Timestamp = $runStampUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'); row_id = $r.row_id; commodity = $r.commodity
    family = 'licensed_upload'; outcome = 'captured'; obs = [int]$obs.Count; kept = ''
    raw_file = (Join-Path $uploadsArchive $archName); reason = ('workbook ' + $wb.Name + ' ticker ' + $ticker)
  })
  Write-Host ("  {0} <- {1}: {2} obs, latest {3}" -f $r.row_id, $ticker, $obs.Count, $obs[$obs.Count - 1].date)
}

$histOut = New-Object System.Collections.Generic.List[object]
foreach ($rid in ($history.Keys | Sort-Object)) {
  foreach ($o in ($history[$rid] | Sort-Object { $_.date })) {
    $histOut.Add([pscustomobject]@{ row_id = $rid; date = [string]$o.date; value = ([double]$o.value).ToString([System.Globalization.CultureInfo]::InvariantCulture) })
  }
}
$histOut | Export-Csv -Path $historyPath -NoTypeInformation -Encoding UTF8

if (-not (Test-Path $captureLogPath)) {
  $logRows | Export-Csv -Path $captureLogPath -NoTypeInformation -Encoding UTF8
} else {
  $logRows | Export-Csv -Path ($captureLogPath + '.tmp') -NoTypeInformation -Encoding UTF8
  Get-Content ($captureLogPath + '.tmp') | Select-Object -Skip 1 | Add-Content -Path $captureLogPath -Encoding UTF8
  Remove-Item ($captureLogPath + '.tmp')
}
Write-Host ("ACCEPTED: {0} ingested; {1} licensed rows updated; workbook archived as {2}" -f $wb.Name, $licRows.Count, $archName)
exit 0
