# capture_all.ps1 — Mission 3 capture engine (spec: docs/capture_spec.md Part B).
# Captures every probe_status=proven row of the newest registry into the consolidated
# history store. Kept-prior doctrine: failures never regress the baseline.
# Licensed rows are fed ONLY by ingest_licensed_uploads.ps1. PS 5.1 compatible.

param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 } catch {}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'xlsx_helpers.ps1')
. (Join-Path $scriptDir 'parse_helpers.ps1')

$runStampUtc = [datetime]::UtcNow
$runLabel = $runStampUtc.ToString('yyyyMMdd_HHmmss')
$rawDir = Join-Path $base ('raw_archive\capture\' + $runLabel)
$cleanedDir = Join-Path $base 'cleaned_data'
$logsDir = Join-Path $base 'logs'
New-Item -ItemType Directory -Force -Path $rawDir, $cleanedDir, $logsDir | Out-Null
$historyPath = Join-Path $cleanedDir 'commodity_series_history.csv'
$captureLogPath = Join-Path $logsDir 'capture_all_log.csv'
$auditPath = Join-Path $logsDir 'source_refresh_audit.csv'

$UA = 'commodity-dashboard-capture/1.0 (procurement research)'
$PaceSeconds = 3
$lastFetch = @{}; $familyAborted = @{}; $fetchCache = @{}

$regFile = Get-NewestRegistry (Join-Path $base 'registry')
$rows = @(Import-Csv -Path $regFile.FullName)
if (-not $Quiet) { Write-Host ("capture run {0} against {1} ({2} rows)" -f $runLabel, $regFile.Name, @($rows).Count) }

$fredKey = Get-LocalKey 'FRED_API_KEY' $base
$eiaKey = Get-LocalKey 'EIA_API_KEY' $base

# ---------- history store (seed unless CMD_NO_SEED=1) ----------
$history = @{}   # row_id -> List of @{date;value([double])}
$noSeed = ([string][Environment]::GetEnvironmentVariable('CMD_NO_SEED')) -eq '1'
if (-not $noSeed -and (Test-Path $historyPath)) {
  foreach ($h in (Import-Csv $historyPath)) {
    if (-not $history.ContainsKey($h.row_id)) { $history[$h.row_id] = New-Object System.Collections.Generic.List[object] }
    $history[$h.row_id].Add(@{ date = [string]$h.date; value = [double]$h.value })
  }
}
$seedNote = ''; if ($noSeed) { $seedNote = ' (CMD_NO_SEED=1: committed history ignored for merge)' }
if (-not $Quiet) { Write-Host ("seeded history rows: {0}{1}" -f $history.Keys.Count, $seedNote) }

# ---------- transport ----------
function Invoke-CaptureFetch {
  param([string]$Url, [string]$Family, [string]$OutFile, [hashtable]$Headers = @{})
  if ($fetchCache.ContainsKey($Url)) {
    $c = $fetchCache[$Url]
    if ($c.file -ne $OutFile) { Copy-Item -Force $c.file $OutFile }
    return @{ ok = $true; status = [int]$c.status; reason = 'cached-shared-fetch' }
  }
  if ($familyAborted.ContainsKey($Family)) { return @{ ok = $false; status = 0; reason = 'family-throttled' } }
  if ($lastFetch.ContainsKey($Family)) {
    $elapsed = ((Get-Date) - $lastFetch[$Family]).TotalSeconds
    if ($elapsed -lt $PaceSeconds) { Start-Sleep -Seconds ([math]::Ceiling($PaceSeconds - $elapsed)) }
  }
  $delays = @(5, 15, 45)
  for ($attempt = 0; $attempt -le 3; $attempt++) {
    $lastFetch[$Family] = Get-Date
    try {
      $h = @{ 'User-Agent' = $UA } + $Headers
      $resp = Invoke-WebRequest -Uri $Url -Headers $h -TimeoutSec 60 -UseBasicParsing -OutFile $OutFile -PassThru
      $fetchCache[$Url] = @{ file = $OutFile; status = [int]$resp.StatusCode }
      return @{ ok = $true; status = [int]$resp.StatusCode; reason = '' }
    } catch {
      $status = 0
      if ($null -ne $_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 } }
      $retryable = ($status -eq 429 -or $status -ge 500 -or $status -eq 0)
      if ($retryable -and $attempt -lt 3) { Start-Sleep -Seconds $delays[$attempt]; continue }
      if ($retryable -and ($status -eq 429 -or $status -ge 500)) { $familyAborted[$Family] = $true; return @{ ok = $false; status = $status; reason = 'family-throttled' } }
      return @{ ok = $false; status = $status; reason = ('http-error: ' + $_.Exception.Message) }
    }
  }
}

# ---------- per-family extraction: return @{ok;obs(List date,value);rawFile;reason} ----------

function Get-WorldbankObs {
  param([object]$Row, [hashtable]$Ctx)
  if (-not $Ctx.ContainsKey('wb_sheet')) {
    $landFile = Join-Path $rawDir 'FAMILY_worldbank_landing.html'
    $lf = Invoke-CaptureFetch -Url $Row.endpoint -Family 'worldbank' -OutFile $landFile
    if (-not $lf.ok) { $Ctx['wb_err'] = ('landing fetch failed: ' + $lf.reason); $Ctx['wb_sheet'] = $null }
    else {
      $m = [regex]::Match((Get-Content $landFile -Raw), 'https://[^"'']*CMO-Historical-Data-Monthly\.xlsx')
      if (-not $m.Success) { $Ctx['wb_err'] = 'no CMO workbook link on landing page'; $Ctx['wb_sheet'] = $null }
      else {
        $wbFile = Join-Path $rawDir 'FAMILY_worldbank_CMO.xlsx'
        $f = Invoke-CaptureFetch -Url $m.Value -Family 'worldbank' -OutFile $wbFile
        if (-not $f.ok) { $Ctx['wb_err'] = $f.reason; $Ctx['wb_sheet'] = $null }
        else {
          $sheet = Read-XlsxSheet -Path $wbFile -SheetName 'Monthly Prices'
          $lblRow = $null
          foreach ($sr in $sheet) {
            foreach ($v in $sr.Cells.Values) { if ((Normalize-CmoLabel ([string]$v)) -eq 'Cocoa') { $lblRow = $sr; break } }
            if ($null -ne $lblRow) { break }
          }
          if ($null -eq $lblRow) { $Ctx['wb_err'] = 'label row not found'; $Ctx['wb_sheet'] = $null }
          else {
            $map = @{}
            foreach ($k in $lblRow.Cells.Keys) { $map[(Normalize-CmoLabel ([string]$lblRow.Cells[$k]))] = [int]$k }
            $Ctx['wb_sheet'] = @($sheet | Where-Object { $_.Cells.ContainsKey(1) -and ([string]$_.Cells[1]) -match '^\d{4}M\d{2}$' })
            $Ctx['wb_map'] = $map
            $Ctx['wb_file'] = $wbFile
          }
        }
      }
    }
  }
  if ($null -eq $Ctx['wb_sheet']) { return @{ ok = $false; reason = [string]$Ctx['wb_err']; rawFile = '' } }
  $lbl = Normalize-CmoLabel ([string]$Row.series_code)
  $map = $Ctx['wb_map']
  if (-not $map.ContainsKey($lbl)) { return @{ ok = $false; reason = ('label not in workbook: ' + $lbl); rawFile = [string]$Ctx['wb_file'] } }
  $col = [int]$map[$lbl]
  $obs = New-Object System.Collections.Generic.List[object]
  foreach ($dr in $Ctx['wb_sheet']) {
    $cellVal = ''
    if ($dr.Cells.ContainsKey($col)) { $cellVal = [string]$dr.Cells[$col] }
    if (Test-MissingMarker $cellVal) { continue }
    $v = Parse-PriceLoose $cellVal
    if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable value "' + $cellVal + '" at ' + $dr.Cells[1]); rawFile = [string]$Ctx['wb_file'] } }
    $obs.Add(@{ date = (Convert-PeriodToIso ([string]$dr.Cells[1])); value = [double]$v })
  }
  return @{ ok = $true; obs = $obs; rawFile = [string]$Ctx['wb_file']; reason = '' }
}

function Get-EurostatObs {
  param([object]$Row)
  $out = Join-Path $rawDir ($Row.row_id + '.json')
  $f = Invoke-CaptureFetch -Url $Row.endpoint -Family 'eurostat' -OutFile $out
  if (-not $f.ok) { return @{ ok = $false; reason = $f.reason; rawFile = '' } }
  try {
    $j = (Get-Content $out -Raw -Encoding UTF8) | ConvertFrom-Json
    if ($null -ne $j.error) { return @{ ok = $false; reason = 'api error'; rawFile = $out } }
    $pins = @{}
    foreach ($part in (([string]$Row.series_code) -split '#')) {
      $kv = $part -split '=', 2
      if ($kv.Count -eq 2) { $pins[$kv[0].Trim()] = $kv[1].Trim() }
    }
    $ids = @($j.id); $sizes = @($j.size | ForEach-Object { [int]$_ })
    $strides = @(0) * $sizes.Count
    $acc = 1
    for ($i = $sizes.Count - 1; $i -ge 0; $i--) { $strides[$i] = $acc; $acc = $acc * $sizes[$i] }
    $basis = 0; $tPos = -1
    for ($i = 0; $i -lt $ids.Count; $i++) {
      $d = [string]$ids[$i]
      if ($d -eq 'time') { $tPos = $i; continue }
      if ($pins.ContainsKey($d)) {
        $idx = $j.dimension.$d.category.index.($pins[$d])
        if ($null -eq $idx) { return @{ ok = $false; reason = ('pinned category absent: ' + $d + '=' + $pins[$d]); rawFile = $out } }
        $basis += ([int]$idx) * $strides[$i]
      } elseif ($sizes[$i] -eq 1) { } # single-valued, position 0
      else { return @{ ok = $false; reason = ('unpinned multi-valued dimension: ' + $d); rawFile = $out } }
    }
    if ($tPos -lt 0) { return @{ ok = $false; reason = 'no time dimension'; rawFile = $out } }
    $timeMap = @{}
    foreach ($p in $j.dimension.time.category.index.PSObject.Properties) { $timeMap[[int]$p.Value] = [string]$p.Name }
    $vals = @{}
    foreach ($p in $j.value.PSObject.Properties) { $vals[[long]$p.Name] = [double]$p.Value }
    $obs = New-Object System.Collections.Generic.List[object]
    for ($t = 0; $t -lt $sizes[$tPos]; $t++) {
      $linear = [long]($basis + $t * $strides[$tPos])
      if ($vals.ContainsKey($linear)) {
        $obs.Add(@{ date = (Convert-PeriodToIso $timeMap[$t]); value = [double]$vals[$linear] })
      }
    }
    return @{ ok = $true; obs = $obs; rawFile = $out; reason = '' }
  } catch { return @{ ok = $false; reason = $_.Exception.Message; rawFile = $out } }
}

function Get-AgrifoodObs {
  param([object]$Row)
  $out = Join-Path $rawDir ($Row.row_id + '.json')
  $f = Invoke-CaptureFetch -Url $Row.endpoint -Family 'eu_agrifood' -OutFile $out
  if (-not $f.ok) { return @{ ok = $false; reason = $f.reason; rawFile = '' } }
  try {
    $j = (Get-Content $out -Raw -Encoding UTF8) | ConvertFrom-Json
    $arr = $null
    if ($j -is [System.Array]) { $arr = @($j) }
    else { foreach ($p in $j.PSObject.Properties) { if ($p.Value -is [System.Array]) { $arr = @($p.Value); break } } }
    if ($null -eq $arr -or @($arr).Count -eq 0) { return @{ ok = $false; reason = 'no record array'; rawFile = $out } }
    if (([string]$Row.series_code) -match '=') {
      foreach ($pair in (([string]$Row.series_code) -split ';')) {
        $kv = $pair -split '=', 2
        if ($kv.Count -eq 2) { $fp = $kv[0].Trim(); $fv = $kv[1].Trim(); $arr = @($arr | Where-Object { ([string]$_.$fp) -eq $fv }) }
      }
      if (@($arr).Count -eq 0) { return @{ ok = $false; reason = ('no records after pin: ' + $Row.series_code); rawFile = $out } }
    }
    $propNames = @($arr[0].PSObject.Properties.Name)
    $dateProp = $null
    foreach ($cand in @('endDate', 'referenceDate', 'date', 'beginDate', 'period', 'ym')) { if ($propNames -contains $cand) { $dateProp = $cand; break } }
    $composite = ($null -eq $dateProp -and ($propNames -contains 'year') -and ($propNames -contains 'month'))
    $priceProp = $null
    foreach ($cand in @('price', 'averagePrice', 'avgPrice', 'value')) { if ($propNames -contains $cand) { $priceProp = $cand; break } }
    if (($null -eq $dateProp -and -not $composite) -or $null -eq $priceProp) { return @{ ok = $false; reason = ('props: ' + ($propNames -join ',')); rawFile = $out } }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $byDate = @{}
    foreach ($rec in $arr) {
      $d = $null
      if ($composite) {
        $dt = [datetime]::MinValue
        $cand = ('{0} {1} 01' -f [string]$rec.year, [string]$rec.month)
        foreach ($fmt in @('yyyy MMMM dd', 'yyyy MMM dd')) {
          if ([datetime]::TryParseExact($cand, $fmt, $inv, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) { $d = $dt; break }
        }
      } else { $d = Parse-DateLoose ([string]$rec.$dateProp) }
      if ($null -eq $d) { return @{ ok = $false; reason = ('non-parseable date: ' + [string]$rec.$dateProp); rawFile = $out } }
      $rawPx = [string]$rec.$priceProp
      if (Test-MissingMarker $rawPx) { continue }
      $v = Parse-PriceLoose $rawPx
      if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable price "' + $rawPx + '"'); rawFile = $out } }
      $dateFmt = 'yyyy-MM-dd'
      if ($dateProp -eq 'ym' -or $composite) { $dateFmt = 'yyyy-MM' }
      $key = $d.ToString($dateFmt)
      if ($byDate.ContainsKey($key)) {
        if ([double]$byDate[$key] -ne [double]$v) { return @{ ok = $false; reason = ('ambiguous pin: two values on ' + $key); rawFile = $out } }
      } else { $byDate[$key] = [double]$v }
    }
    $obs = New-Object System.Collections.Generic.List[object]
    foreach ($k in ($byDate.Keys | Sort-Object)) { $obs.Add(@{ date = [string]$k; value = [double]$byDate[$k] }) }
    return @{ ok = $true; obs = $obs; rawFile = $out; reason = '' }
  } catch { return @{ ok = $false; reason = $_.Exception.Message; rawFile = $out } }
}

function Get-FaoObs {
  param([object]$Row, [hashtable]$Ctx)
  if (-not $Ctx.ContainsKey('fao_lines')) {
    $faoFile = Join-Path $rawDir 'FAMILY_fao_fpi.csv'
    $f = Invoke-CaptureFetch -Url $Row.endpoint -Family 'fao' -OutFile $faoFile
    if (-not $f.ok) { $Ctx['fao_lines'] = $null; $Ctx['fao_err'] = $f.reason }
    else { $Ctx['fao_lines'] = @(Get-Content $faoFile); $Ctx['fao_file'] = $faoFile }
  }
  if ($null -eq $Ctx['fao_lines']) { return @{ ok = $false; reason = [string]$Ctx['fao_err']; rawFile = '' } }
  $lines = $Ctx['fao_lines']
  $hdrIdx = -1
  for ($i = 0; $i -lt [math]::Min(10, $lines.Count); $i++) { if ($lines[$i] -match '^Date,') { $hdrIdx = $i; break } }
  if ($hdrIdx -lt 0) { return @{ ok = $false; reason = 'no Date header'; rawFile = [string]$Ctx['fao_file'] } }
  $hdr = $lines[$hdrIdx] -split ','
  $colIdx = -1
  for ($c = 1; $c -lt $hdr.Count; $c++) { if (($hdr[$c]).Trim() -eq [string]$Row.series_code) { $colIdx = $c; break } }
  if ($colIdx -lt 0) { return @{ ok = $false; reason = ('column not found: ' + $Row.series_code); rawFile = [string]$Ctx['fao_file'] } }
  $obs = New-Object System.Collections.Generic.List[object]
  for ($i = $hdrIdx + 1; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i] -split ','
    if ($parts.Count -le $colIdx) { continue }
    $dateStr = ([string]$parts[0]).Trim()
    if ($dateStr -eq '') { continue }
    $cellVal = ([string]$parts[$colIdx]).Trim()
    if (Test-MissingMarker $cellVal) { continue }
    $v = Parse-PriceLoose $cellVal
    if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable value "' + $cellVal + '" at ' + $dateStr); rawFile = [string]$Ctx['fao_file'] } }
    $obs.Add(@{ date = (Convert-PeriodToIso $dateStr); value = [double]$v })
  }
  return @{ ok = $true; obs = $obs; rawFile = [string]$Ctx['fao_file']; reason = '' }
}

function Get-FredObs {
  param([object]$Row)
  if ([string]::IsNullOrEmpty($fredKey)) { return @{ ok = $false; reason = 'FRED_API_KEY absent'; rawFile = '' } }
  $out = Join-Path $rawDir ($Row.row_id + '.json')
  $f = Invoke-CaptureFetch -Url (([string]$Row.endpoint) -replace '\{KEY\}', $fredKey) -Family 'fred' -OutFile $out
  if (-not $f.ok) { return @{ ok = $false; reason = $f.reason; rawFile = '' } }
  try {
    $j = (Get-Content $out -Raw -Encoding UTF8) | ConvertFrom-Json
    $obs = New-Object System.Collections.Generic.List[object]
    foreach ($o in @($j.observations)) {
      if (Test-MissingMarker ([string]$o.value)) { continue }
      $v = Parse-PriceLoose ([string]$o.value)
      if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable value "' + $o.value + '"'); rawFile = $out } }
      $obs.Add(@{ date = ([string]$o.date).Substring(0, 7); value = [double]$v })
    }
    return @{ ok = $true; obs = $obs; rawFile = $out; reason = '' }
  } catch { return @{ ok = $false; reason = $_.Exception.Message; rawFile = $out } }
}

function Get-EiaObs {
  param([object]$Row)
  if ([string]::IsNullOrEmpty($eiaKey)) { return @{ ok = $false; reason = 'EIA_API_KEY absent'; rawFile = '' } }
  $out = Join-Path $rawDir ($Row.row_id + '.json')
  $f = Invoke-CaptureFetch -Url (([string]$Row.endpoint) -replace '\{KEY\}', $eiaKey) -Family 'eia' -OutFile $out
  if (-not $f.ok) { return @{ ok = $false; reason = $f.reason; rawFile = '' } }
  # EIA echoes api_key in the response 'request' block — scrub before it is archived/committed
  try { $rawTxt = [System.IO.File]::ReadAllText($out); if ($rawTxt.Contains($eiaKey)) { [System.IO.File]::WriteAllText($out, ($rawTxt -replace [regex]::Escape($eiaKey), '{KEY}'), (New-Object System.Text.UTF8Encoding($false))) } } catch {}
  try {
    $j = (Get-Content $out -Raw -Encoding UTF8) | ConvertFrom-Json
    $data = @($j.response.data)
    if (@($data).Count -eq 0) { return @{ ok = $false; reason = 'no response.data'; rawFile = $out } }
    $byDate = @{}
    foreach ($d in $data) {
      $per = [string]$d.period
      if ($per -eq '') { continue }
      $rawv = [string]$d.value
      if (Test-MissingMarker $rawv) { continue }
      $v = Parse-PriceLoose $rawv
      if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable value "' + $rawv + '"'); rawFile = $out } }
      if ($byDate.ContainsKey($per)) { if ([double]$byDate[$per] -ne [double]$v) { return @{ ok = $false; reason = ('ambiguous: two values on ' + $per); rawFile = $out } } }
      else { $byDate[$per] = [double]$v }
    }
    $obs = New-Object System.Collections.Generic.List[object]
    foreach ($k in ($byDate.Keys | Sort-Object)) { $obs.Add(@{ date = [string]$k; value = [double]$byDate[$k] }) }
    return @{ ok = $true; obs = $obs; rawFile = $out; reason = '' }
  } catch { return @{ ok = $false; reason = $_.Exception.Message; rawFile = $out } }
}

function Get-EuOilObs {
  param([object]$Row, [hashtable]$Ctx)
  if (-not $Ctx.ContainsKey('oil_xl')) {
    $landFile = Join-Path $rawDir 'FAMILY_euoil_landing.html'
    $lf = Invoke-CaptureFetch -Url $Row.endpoint -Family 'eu_oil_bulletin' -OutFile $landFile
    if (-not $lf.ok) { $Ctx['oil_xl'] = $null; $Ctx['oil_err'] = $lf.reason }
    else {
      $m = [regex]::Match((Get-Content $landFile -Raw), 'href="(/document/download/[^"]*Prices_History[^"]*\.xlsx[^"]*)"')
      if (-not $m.Success) { $Ctx['oil_xl'] = $null; $Ctx['oil_err'] = 'no Prices_History xlsx link on landing' }
      else {
        $href = $m.Groups[1].Value -replace '&amp;', '&'
        $u = [Uri]$Row.endpoint; $full = $u.Scheme + '://' + $u.Host + $href
        $xlFile = Join-Path $rawDir 'FAMILY_euoil.xlsx'
        $xf = Invoke-CaptureFetch -Url $full -Family 'eu_oil_bulletin' -OutFile $xlFile
        if (-not $xf.ok) { $Ctx['oil_xl'] = $null; $Ctx['oil_err'] = $xf.reason } else { $Ctx['oil_xl'] = $xlFile }
      }
    }
  }
  if ($null -eq $Ctx['oil_xl']) { return @{ ok = $false; reason = [string]$Ctx['oil_err']; rawFile = '' } }
  try {
    $parts = ([string]$Row.series_code) -split '#'
    $sheet = Read-XlsxSheet -Path $Ctx['oil_xl'] -SheetName $parts[0]
    $fuel = $parts[1]
    $labelRow = $null
    foreach ($sr in $sheet) { if ([int]$sr.RowIndex -eq 2) { $labelRow = $sr; break } }
    $fuelCol = -1
    if ($null -ne $labelRow) { foreach ($k in ($labelRow.Cells.Keys | Sort-Object { [int]$_ })) { if (([string]$labelRow.Cells[$k]) -match [regex]::Escape($fuel)) { $fuelCol = [int]$k; break } } }
    if ($fuelCol -lt 0) { return @{ ok = $false; reason = ('fuel column not found: ' + $fuel); rawFile = $Ctx['oil_xl'] } }
    $byDate = @{}
    foreach ($sr in $sheet) {
      if ([int]$sr.RowIndex -lt 4) { continue }
      if (-not $sr.Cells.ContainsKey(1) -or -not $sr.Cells.ContainsKey(2)) { continue }
      if (([string]$sr.Cells[2]).Trim() -ne 'EU_') { continue }
      $serial = Parse-PriceLoose ([string]$sr.Cells[1])
      if ($null -eq $serial) { continue }
      $dt = [datetime]::FromOADate([double]$serial).ToString('yyyy-MM-dd')
      $cellv = ''
      if ($sr.Cells.ContainsKey($fuelCol)) { $cellv = [string]$sr.Cells[$fuelCol] }
      if (Test-MissingMarker $cellv) { continue }
      $v = Parse-PriceLoose $cellv
      if ($null -eq $v) { return @{ ok = $false; reason = ('non-castable "' + $cellv + '" at ' + $dt); rawFile = $Ctx['oil_xl'] } }
      $val = [math]::Round([double]$v / 1000.0, 6)   # EUR/1000L -> EUR/L
      if ($byDate.ContainsKey($dt)) { if ([double]$byDate[$dt] -ne $val) { return @{ ok = $false; reason = ('ambiguous on ' + $dt); rawFile = $Ctx['oil_xl'] } } }
      else { $byDate[$dt] = $val }
    }
    if ($byDate.Count -eq 0) { return @{ ok = $false; reason = 'no EU_ observations'; rawFile = $Ctx['oil_xl'] } }
    $obs = New-Object System.Collections.Generic.List[object]
    foreach ($k in ($byDate.Keys | Sort-Object)) { $obs.Add(@{ date = [string]$k; value = [double]$byDate[$k] }) }
    return @{ ok = $true; obs = $obs; rawFile = $Ctx['oil_xl']; reason = '' }
  } catch { return @{ ok = $false; reason = $_.Exception.Message; rawFile = $Ctx['oil_xl'] } }
}

# ---------- run ----------
$logRows = New-Object System.Collections.Generic.List[object]
$auditRows = New-Object System.Collections.Generic.List[object]
$ctx = @{}
$counts = @{ captured = 0; kept_prior = 0; not_captured = 0 }
$famOrder = @('worldbank', 'eurostat', 'eu_agrifood', 'fao', 'fred', 'usda', 'icco', 'ico', 'mpob', 'licensed_upload')
$sorted = @($rows | Sort-Object { [array]::IndexOf($famOrder, $_.source_family) }, row_id)

foreach ($r in $sorted) {
  $fam = [string]$r.source_family
  $eligible = ($r.probe_status -eq 'proven')
  $res = $null
  if ($eligible) {
    switch ($fam) {
      'worldbank'   { $res = Get-WorldbankObs -Row $r -Ctx $ctx }
      'eurostat'    { $res = Get-EurostatObs -Row $r }
      'eu_agrifood' { $res = Get-AgrifoodObs -Row $r }
      'fao'         { $res = Get-FaoObs -Row $r -Ctx $ctx }
      'fred'        { $res = Get-FredObs -Row $r }
      'eia'         { $res = Get-EiaObs -Row $r }
      'eu_oil_bulletin' { $res = Get-EuOilObs -Row $r -Ctx $ctx }
      default       { $res = @{ ok = $false; reason = ('family parser deferred until probe proof: ' + $fam); rawFile = '' } }
    }
  }

  $outcome = ''; $reason = ''; $obsN = 0; $kept = ''; $rawFile = ''
  $latestFresh = ''; $histSource = 'none'
  if (-not $eligible) {
    $outcome = 'not_captured'
    if ($r.access -eq 'licensed-upload') { $reason = 'licensed lane: fed by ingest_licensed_uploads.ps1 only' }
    elseif ($r.probe_status -eq 'watchlist') { $reason = 'on watchlist (gaps file)' }
    else { $reason = 'probe_status=' + $r.probe_status + ' (not proven; e.g. awaiting key)' }
    $counts.not_captured++
  } else {
    $rawFile = [string]$res.rawFile
    if ($res.ok) {
      $obsN = [int]$res.obs.Count
      if ($obsN -lt 6) { $res = @{ ok = $false; reason = ('only ' + $obsN + ' obs (<6) on this fetch'); rawFile = $rawFile } }
    }
    if ($res.ok) {
      $history[$r.row_id] = $res.obs
      $outcome = 'captured'
      $latestFresh = [string]$res.obs[$res.obs.Count - 1].date
      $histSource = 'fresh-from-source'
      $counts.captured++
    } else {
      $outcome = 'kept_prior'
      $reason = [string]$res.reason
      if ($history.ContainsKey($r.row_id)) { $kept = 'kept-prior'; $histSource = 'kept-prior' }
      $counts.kept_prior++
    }
  }
  $latestFinal = ''
  if ($history.ContainsKey($r.row_id) -and $history[$r.row_id].Count -gt 0) {
    $latestFinal = [string]($history[$r.row_id] | Sort-Object { $_.date } | Select-Object -Last 1).date
  }
  $logRows.Add([pscustomobject]@{
    Timestamp = $runStampUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'); row_id = $r.row_id; commodity = $r.commodity
    family = $fam; outcome = $outcome; obs = [int]$obsN; kept = $kept; raw_file = $rawFile; reason = $reason
  })
  $auditRows.Add([pscustomobject]@{
    row_id = $r.row_id; commodity = $r.commodity; source_family = $fam
    attempted_this_run = $eligible; fetch_succeeded = ($outcome -eq 'captured')
    observations_fetched = [int]$obsN; history_source = $histSource
    latest_date_fresh = $latestFresh; latest_date_final = $latestFinal; failure_reason = $reason
  })
  if (-not $Quiet) { Write-Host ("  {0} [{1}] -> {2} (obs={3}, latest={4}) {5}" -f $r.row_id, $fam, $outcome, $obsN, $latestFinal, $reason) }
}

# ---------- persist ----------
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
$auditRows | Export-Csv -Path $auditPath -NoTypeInformation -Encoding UTF8

$totalObs = [int]$histOut.Count
Write-Host ''
Write-Host ("=== capture run {0} summary ===" -f $runLabel)
Write-Host ("  captured = {0}; kept_prior = {1}; not_captured = {2}" -f [int]$counts.captured, [int]$counts.kept_prior, [int]$counts.not_captured)
Write-Host ("  history store: {0} observations across {1} series" -f $totalObs, $history.Keys.Count)
Write-Host ("  history: {0}" -f $historyPath)
exit 0
