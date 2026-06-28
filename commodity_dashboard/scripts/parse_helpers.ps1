# parse_helpers.ps1 — pure parsing/normalisation functions shared by probe_endpoints.ps1,
# capture_all.ps1 and ingest_licensed_uploads.ps1. No state, no I/O.
# Windows PowerShell 5.1 compatible.

$script:CmdMissingMarkers = @('', '.', '..', '...', ([char]0x2026).ToString())

function Parse-DateLoose([string]$s) {
  $dt = [datetime]::MinValue
  $styles = [System.Globalization.DateTimeStyles]::None
  $inv = [System.Globalization.CultureInfo]::InvariantCulture
  foreach ($fmt in @('dd/MM/yyyy', 'yyyy-MM-dd', 'yyyy-MM-ddTHH:mm:ss', 'MM/dd/yyyy', 'yyyy/MM', 'yyyy-MM')) {
    if ([datetime]::TryParseExact($s, $fmt, $inv, $styles, [ref]$dt)) { return $dt }
  }
  if ([datetime]::TryParse($s, $inv, $styles, [ref]$dt)) { return $dt }
  return $null
}

function Parse-PriceLoose([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $d0 = [double]0
  # direct parse first: handles plain numerics incl. scientific notation (Excel XML
  # stores 0.07 as 7.0000000000000007E-2 — the stripping heuristic would mangle the E)
  if ([double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d0)) { return [double]$d0 }
  $t = ($s -replace '[^\d\.,\-]', '')
  if ($t -eq '') { return $null }
  if ($t.Contains('.') -and $t.Contains(',')) { $t = $t -replace ',', '' }
  elseif ($t.Contains(',') -and -not $t.Contains('.')) { $t = $t -replace ',', '.' }
  $d = [double]0
  if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return [double]$d }
  return $null
}

function Test-MissingMarker([string]$s) {
  # Recognised absent-observation markers (skipped); anything else non-castable FAILS a row.
  return ($script:CmdMissingMarkers -contains ([string]$s).Trim())
}

function Normalize-CmoLabel([string]$s) { return (($s -replace '\*', '')).Trim() }

function Convert-PeriodToIso([string]$p) {
  # '2026M05' -> '2026-05' ; '2026-Q1' -> '2026-03' (quarter-end month) ; passthrough otherwise
  $p = ([string]$p).Trim()
  if ($p -match '^(\d{4})M(\d{2})$') { return ('{0}-{1}' -f $Matches[1], $Matches[2]) }
  if ($p -match '^(\d{4})-Q([1-4])$') {
    $endMonth = @{ '1' = '03'; '2' = '06'; '3' = '09'; '4' = '12' }[$Matches[2]]
    return ('{0}-{1}' -f $Matches[1], $endMonth)
  }
  return $p
}

function Get-NewestRegistry([string]$RegistryDir) {
  $files = Get-ChildItem -Path $RegistryDir -Filter 'commodity_registry_v*_active.csv' |
    Sort-Object { [int]([regex]::Match($_.Name, 'v(\d+)_active').Groups[1].Value) } -Descending
  if (-not $files -or @($files).Count -eq 0) { throw "no registry found in $RegistryDir" }
  return $files[0]
}

function Get-LocalKey([string]$Name, [string]$ProjectBase) {
  $v = [Environment]::GetEnvironmentVariable($Name)
  if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
  $envp = Join-Path $ProjectBase '.env'
  if (Test-Path $envp) {
    foreach ($line in (Get-Content $envp)) {
      $kv = $line -split '=', 2
      if ($kv.Count -eq 2 -and $kv[0].Trim() -eq $Name) { return $kv[1].Trim().Trim('"') }
    }
  }
  return $null
}
