# probe_endpoints.ps1 — Mission 2 probe engine (spec: docs/capture_spec.md Part A).
# Probes every access=open / open-with-key row of the newest registry; never fetches
# licensed rows. Archives every response. Windows PowerShell 5.1 compatible.

param([string]$PassLabel = '')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 } catch {}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir 'xlsx_helpers.ps1')
. (Join-Path $scriptDir 'parse_helpers.ps1')

if ($PassLabel -eq '') { $PassLabel = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss') }
$probeRoot = Join-Path $base 'raw_archive\probes'
$passDir = Join-Path $probeRoot $PassLabel
New-Item -ItemType Directory -Force -Path $passDir | Out-Null

$UA = 'commodity-dashboard-probe/1.0 (procurement research)'
$PaceSeconds = 3
$lastFetch = @{}        # family -> [datetime] last physical fetch
$familyAborted = @{}    # family -> $true after persistent throttling
$fetchCache = @{}       # url -> @{file;status} (dedupes shared fetches within a pass)
$results = New-Object System.Collections.Generic.List[object]
$triage = New-Object System.Collections.Generic.List[string]

# --- registry (newest version) ---
$regFiles = Get-ChildItem -Path (Join-Path $base 'registry') -Filter 'commodity_registry_v*_active.csv' |
  Sort-Object { [int]([regex]::Match($_.Name, 'v(\d+)_active').Groups[1].Value) } -Descending
$regPath = $regFiles[0].FullName
$rows = @(Import-Csv -Path $regPath)
Write-Host ("Probe pass {0} against {1} ({2} rows)" -f $PassLabel, $regFiles[0].Name, @($rows).Count)

# --- keys (env first, then git-ignored .env at project base) — shared helper ---
$fredKey = Get-LocalKey 'FRED_API_KEY' $base
$usdaKey = Get-LocalKey 'USDA_FAS_KEY' $base
$eiaKey = Get-LocalKey 'EIA_API_KEY' $base

function Invoke-ProbeFetch {
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
      if ($retryable -and $attempt -lt 3) {
        Write-Host ("  retry {0}/3 after {1}s (status {2}) {3}" -f ($attempt + 1), $delays[$attempt], $status, $Url)
        Start-Sleep -Seconds $delays[$attempt]
        continue
      }
      if ($retryable -and $attempt -ge 3 -and ($status -eq 429 -or $status -ge 500)) {
        $familyAborted[$Family] = $true
        return @{ ok = $false; status = $status; reason = 'family-throttled' }
      }
      return @{ ok = $false; status = $status; reason = ('http-error: ' + $_.Exception.Message) }
    }
  }
}

function Add-Result {
  param([string]$RowId, [string]$Family, [string]$Outcome, [int]$Status, [int]$Obs,
        [string]$First, [string]$Last, [string]$Latest, [string]$RawFile, [string]$Reason)
  $results.Add([pscustomobject]@{
    pass = $PassLabel; row_id = $RowId; family = $Family; outcome = $Outcome
    http_status = $Status; obs_count = $Obs; first_date = $First; last_date = $Last
    latest_value = $Latest; unit_sane = 'tbd'; raw_file = $RawFile; reason = $Reason
  })
  Write-Host ("  {0} -> {1} (obs={2}, last={3}, latest={4}) {5}" -f $RowId, $Outcome, $Obs, $Last, $Latest, $Reason)
}

# Parse-DateLoose / Parse-PriceLoose / Normalize-CmoLabel come from parse_helpers.ps1.

# ============================== watchlist rows: skipped ==============================
foreach ($r in @($rows | Where-Object { $_.probe_status -eq 'watchlist' })) {
  Add-Result $r.row_id $r.source_family 'skipped-watchlist' 0 0 '' '' '' '' 'on watchlist with documented reproduction; not probed'
}
$rows = @($rows | Where-Object { $_.probe_status -ne 'watchlist' })

# ============================== FAMILY: worldbank ==============================
$wbRows = @($rows | Where-Object { $_.source_family -eq 'worldbank' })
if (@($wbRows).Count -gt 0) {
  Write-Host '--- family: worldbank (landing-page resolver + one shared CMO workbook fetch) ---'
  $wbUrl = [string]$wbRows[0].endpoint
  $resolveOk = $true
  if ($wbUrl -notmatch '\.xlsx') {
    $landFile = Join-Path $passDir ('FAMILY_worldbank_landing_' + $PassLabel + '.html')
    $lf = Invoke-ProbeFetch -Url $wbUrl -Family 'worldbank' -OutFile $landFile
    if (-not $lf.ok) {
      foreach ($r in $wbRows) { Add-Result $r.row_id 'worldbank' 'failed-fetch' $lf.status 0 '' '' '' '' ('landing fetch failed: ' + $lf.reason) }
      $resolveOk = $false
    } else {
      $html = Get-Content $landFile -Raw
      $m = [regex]::Match($html, 'https://[^"'']*CMO-Historical-Data-Monthly\.xlsx')
      if (-not $m.Success) {
        foreach ($r in $wbRows) { Add-Result $r.row_id 'worldbank' 'failed-parse' $lf.status 0 '' '' '' $landFile 'no CMO-Historical-Data-Monthly.xlsx link on landing page' }
        $resolveOk = $false
      } else {
        $wbUrl = $m.Value
        $triage.Add('worldbank resolved workbook: ' + $wbUrl)
      }
    }
  }
  if (-not $resolveOk) { $wbRows = @() }
}
if (@($wbRows).Count -gt 0) {
  $wbFile = Join-Path $passDir ('FAMILY_worldbank_' + $PassLabel + '.xlsx')
  $f = Invoke-ProbeFetch -Url $wbUrl -Family 'worldbank' -OutFile $wbFile
  if (-not $f.ok) {
    foreach ($r in $wbRows) { Add-Result $r.row_id 'worldbank' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason }
  } else {
    try {
      $sheet = Read-XlsxSheet -Path $wbFile -SheetName 'Monthly Prices'
      $codeRow = $null
      foreach ($sr in $sheet) {
        $hit = $false
        foreach ($v in $sr.Cells.Values) { if ((Normalize-CmoLabel ([string]$v)) -eq 'Cocoa') { $hit = $true; break } }
        if ($hit) { $codeRow = $sr; break }
      }
      if ($null -eq $codeRow) { throw 'label row (containing Cocoa) not found in Monthly Prices' }
      $codeMap = @{}
      foreach ($k in $codeRow.Cells.Keys) { $codeMap[(Normalize-CmoLabel ([string]$codeRow.Cells[$k]))] = [int]$k }
      $dataRows = @($sheet | Where-Object { $_.Cells.ContainsKey(1) -and ([string]$_.Cells[1]) -match '^\d{4}M\d{2}$' })
      $avail = ($codeMap.Keys | Where-Object { $_ -match '^[A-Z]' } | Sort-Object) -join '; '
      $triage.Add('worldbank CMO available labels: ' + $avail)
      foreach ($r in $wbRows) {
        $lbl = Normalize-CmoLabel ([string]$r.series_code)
        if (-not $codeMap.ContainsKey($lbl)) {
          Add-Result $r.row_id 'worldbank' 'failed-parse' 200 0 '' '' '' $wbFile ('series label not in workbook: ' + $lbl)
          continue
        }
        $col = [int]$codeMap[$lbl]
        $obs = New-Object System.Collections.Generic.List[object]
        foreach ($dr in $dataRows) {
          if ($dr.Cells.ContainsKey($col)) {
            $v = Parse-PriceLoose ([string]$dr.Cells[$col])
            if ($null -ne $v) { $obs.Add(@{ p = [string]$dr.Cells[1]; v = [double]$v }) }
          }
        }
        if ($obs.Count -eq 0) { Add-Result $r.row_id 'worldbank' 'failed-parse' 200 0 '' '' '' $wbFile 'no castable observations' }
        else { Add-Result $r.row_id 'worldbank' 'ok' 200 ([int]$obs.Count) $obs[0].p $obs[$obs.Count-1].p ([string]$obs[$obs.Count-1].v) $wbFile '' }
      }
    } catch {
      foreach ($r in $wbRows) { Add-Result $r.row_id 'worldbank' 'failed-parse' 200 0 '' '' '' $wbFile $_.Exception.Message }
    }
  }
}

# ============================== FAMILY: fred ==============================
$fredRows = @($rows | Where-Object { $_.source_family -eq 'fred' })
if (@($fredRows).Count -gt 0) {
  Write-Host '--- family: fred ---'
  foreach ($r in $fredRows) {
    if ([string]::IsNullOrEmpty($fredKey)) { Add-Result $r.row_id 'fred' 'blocked-no-key' 0 0 '' '' '' '' 'FRED_API_KEY absent (env/.env)'; continue }
    $out = Join-Path $passDir ($r.row_id + '_' + $PassLabel + '.json')
    $url = $r.endpoint -replace '\{KEY\}', $fredKey
    $f = Invoke-ProbeFetch -Url $url -Family 'fred' -OutFile $out
    if (-not $f.ok) { Add-Result $r.row_id 'fred' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; continue }
    try {
      $j = (Get-Content $out -Raw) | ConvertFrom-Json
      $obs = @($j.observations | Where-Object { $_.value -ne '.' })
      if (@($obs).Count -eq 0) { Add-Result $r.row_id 'fred' 'failed-parse' $f.status 0 '' '' '' $out 'no observations'; continue }
      $lastO = $obs[@($obs).Count - 1]
      Add-Result $r.row_id 'fred' 'ok' $f.status ([int]@($obs).Count) $obs[0].date $lastO.date ([string]([double]$lastO.value)) $out ''
    } catch { Add-Result $r.row_id 'fred' 'failed-parse' $f.status 0 '' '' '' $out $_.Exception.Message }
  }
}

# ============================== FAMILY: eia ==============================
$eiaRows = @($rows | Where-Object { $_.source_family -eq 'eia' })
if (@($eiaRows).Count -gt 0) {
  Write-Host '--- family: eia ---'
  foreach ($r in $eiaRows) {
    if ([string]::IsNullOrEmpty($eiaKey)) { Add-Result $r.row_id 'eia' 'blocked-no-key' 0 0 '' '' '' '' 'EIA_API_KEY absent (env/.env)'; continue }
    $out = Join-Path $passDir ($r.row_id + '_' + $PassLabel + '.json')
    $url = $r.endpoint -replace '\{KEY\}', $eiaKey
    $f = Invoke-ProbeFetch -Url $url -Family 'eia' -OutFile $out
    if (-not $f.ok) { Add-Result $r.row_id 'eia' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; continue }
    # EIA echoes api_key in the response 'request' block — scrub before it is archived/committed
    try { $rawTxt = [System.IO.File]::ReadAllText($out); if ($rawTxt.Contains($eiaKey)) { [System.IO.File]::WriteAllText($out, ($rawTxt -replace [regex]::Escape($eiaKey), '{KEY}'), (New-Object System.Text.UTF8Encoding($false))) } } catch {}
    try {
      $j = (Get-Content $out -Raw -Encoding UTF8) | ConvertFrom-Json
      $data = @($j.response.data)
      if (@($data).Count -eq 0) { Add-Result $r.row_id 'eia' 'failed-parse' $f.status 0 '' '' '' $out 'no response.data'; continue }
      $parsed = New-Object System.Collections.Generic.List[object]
      foreach ($d in $data) {
        $v = Parse-PriceLoose ([string]$d.value)
        if ($null -ne $v -and ([string]$d.period) -ne '') { $parsed.Add(@{ p = [string]$d.period; v = [double]$v }) }
      }
      if ($parsed.Count -eq 0) { Add-Result $r.row_id 'eia' 'failed-parse' $f.status 0 '' '' '' $out 'no castable observations'; continue }
      $sorted = @($parsed | Sort-Object { $_.p })
      Add-Result $r.row_id 'eia' 'ok' $f.status ([int]$sorted.Count) $sorted[0].p $sorted[$sorted.Count-1].p ([string]$sorted[$sorted.Count-1].v) $out ''
    } catch { Add-Result $r.row_id 'eia' 'failed-parse' $f.status 0 '' '' '' $out $_.Exception.Message }
  }
}

# ============================== FAMILY: eu_oil_bulletin ==============================
$oilRows = @($rows | Where-Object { $_.source_family -eq 'eu_oil_bulletin' })
if (@($oilRows).Count -gt 0) {
  Write-Host '--- family: eu_oil_bulletin (landing resolver + shared history xlsx) ---'
  $landUrl = [string]$oilRows[0].endpoint
  $landFile = Join-Path $passDir ('FAMILY_euoil_landing_' + $PassLabel + '.html')
  $lf = Invoke-ProbeFetch -Url $landUrl -Family 'eu_oil_bulletin' -OutFile $landFile
  $xlOk = $false; $xlFile = ''
  if ($lf.ok) {
    $html = Get-Content $landFile -Raw
    $m = [regex]::Match($html, 'href="(/document/download/[^"]*Prices_History[^"]*\.xlsx[^"]*)"')
    if ($m.Success) {
      $href = $m.Groups[1].Value -replace '&amp;', '&'
      $u = [Uri]$landUrl
      $full = $u.Scheme + '://' + $u.Host + $href
      $triage.Add('eu_oil_bulletin resolved history: ' + $full)
      $xlFile = Join-Path $passDir ('FAMILY_euoil_' + $PassLabel + '.xlsx')
      $xf = Invoke-ProbeFetch -Url $full -Family 'eu_oil_bulletin' -OutFile $xlFile
      if ($xf.ok) { $xlOk = $true }
    }
  }
  if (-not $xlOk) {
    foreach ($r in $oilRows) { Add-Result $r.row_id 'eu_oil_bulletin' 'failed-fetch' $lf.status 0 '' '' '' '' 'could not resolve/fetch Prices_History xlsx from landing' }
  } else {
    foreach ($r in $oilRows) {
      try {
        $parts = ([string]$r.series_code) -split '#'
        $sheetName = $parts[0]; $fuel = $parts[1]
        $sheet = Read-XlsxSheet -Path $xlFile -SheetName $sheetName
        $fuelCol = -1; $labelRow = $null
        foreach ($sr in $sheet) { if ([int]$sr.RowIndex -eq 2) { $labelRow = $sr; break } }
        # keys iterate unordered AND the fuel labels repeat per-country across the sheet;
        # take the FIRST (lowest-index) match = the EU aggregate block (CTR 'EU_' in col 2).
        if ($null -ne $labelRow) { foreach ($k in ($labelRow.Cells.Keys | Sort-Object { [int]$_ })) { if (([string]$labelRow.Cells[$k]) -match [regex]::Escape($fuel)) { $fuelCol = [int]$k; break } } }
        if ($fuelCol -lt 0) { Add-Result $r.row_id 'eu_oil_bulletin' 'failed-parse' 200 0 '' '' '' $xlFile ('fuel column not found: ' + $fuel); continue }
        $obs = New-Object System.Collections.Generic.List[object]
        foreach ($sr in $sheet) {
          if ([int]$sr.RowIndex -lt 4) { continue }
          if (-not $sr.Cells.ContainsKey(1) -or -not $sr.Cells.ContainsKey(2)) { continue }
          if (([string]$sr.Cells[2]).Trim() -ne 'EU_') { continue }
          $serial = Parse-PriceLoose ([string]$sr.Cells[1])
          if ($null -eq $serial) { continue }
          $dt = [datetime]::FromOADate([double]$serial)
          if (-not $sr.Cells.ContainsKey($fuelCol)) { continue }
          $raw = Parse-PriceLoose ([string]$sr.Cells[$fuelCol])
          if ($null -eq $raw) { continue }
          $obs.Add(@{ d = $dt; v = [double]$raw / 1000.0 })
        }
        if ($obs.Count -eq 0) { Add-Result $r.row_id 'eu_oil_bulletin' 'failed-parse' 200 0 '' '' '' $xlFile 'no EU_ observations'; continue }
        $sorted = @($obs | Sort-Object { $_.d })
        Add-Result $r.row_id 'eu_oil_bulletin' 'ok' 200 ([int]$obs.Count) $sorted[0].d.ToString('yyyy-MM-dd') $sorted[$sorted.Count-1].d.ToString('yyyy-MM-dd') ([string][math]::Round($sorted[$sorted.Count-1].v,4)) $xlFile ('fuelCol=' + $fuelCol)
      } catch { Add-Result $r.row_id 'eu_oil_bulletin' 'failed-parse' 200 0 '' '' '' $xlFile $_.Exception.Message }
    }
  }
}

# ============================== FAMILY: eurostat ==============================
$esRows = @($rows | Where-Object { $_.source_family -eq 'eurostat' })
if (@($esRows).Count -gt 0) {
  Write-Host '--- family: eurostat ---'
  foreach ($r in $esRows) {
    $out = Join-Path $passDir ($r.row_id + '_' + $PassLabel + '.json')
    $f = Invoke-ProbeFetch -Url $r.endpoint -Family 'eurostat' -OutFile $out
    if (-not $f.ok) { Add-Result $r.row_id 'eurostat' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; continue }
    try {
      $j = (Get-Content $out -Raw) | ConvertFrom-Json
      if ($null -ne $j.error) { Add-Result $r.row_id 'eurostat' 'failed-parse' $f.status 0 '' '' '' $out ('api error: ' + (($j.error | ConvertTo-Json -Compress -Depth 4) -replace '\s+', ' ')); continue }
      $ids = @($j.id); $sizes = @($j.size | ForEach-Object { [int]$_ })
      $tPos = [array]::IndexOf($ids, 'time')
      $timeIdx = $j.dimension.time.category.index
      $timeMap = @{}   # position -> period label
      foreach ($p in $timeIdx.PSObject.Properties) { $timeMap[[int]$p.Value] = [string]$p.Name }
      $timeSize = [int]$sizes[$tPos]
      $stride = 1; for ($i = $tPos + 1; $i -lt $sizes.Count; $i++) { $stride = $stride * [int]$sizes[$i] }
      $vals = @{}      # linear index -> double
      foreach ($p in $j.value.PSObject.Properties) { $vals[[long]$p.Name] = [double]$p.Value }
      if ($vals.Count -eq 0) { Add-Result $r.row_id 'eurostat' 'failed-parse' $f.status 0 '' '' '' $out 'empty value set'; continue }
      $bestT = -1; $bestLinear = [long]-1; $minT = [int]::MaxValue
      foreach ($k in $vals.Keys) {
        $tp = [int](([long]$k / $stride) % $timeSize)
        if ($tp -gt $bestT) { $bestT = $tp; $bestLinear = [long]$k }
        elseif ($tp -eq $bestT -and ([long]$k) -lt $bestLinear) { $bestLinear = [long]$k }
        if ($tp -lt $minT) { $minT = $tp }
      }
      Add-Result $r.row_id 'eurostat' 'ok' $f.status ([int]$vals.Count) $timeMap[$minT] $timeMap[$bestT] ([string]$vals[$bestLinear]) $out ('dims=' + ($ids -join '|'))
    } catch { Add-Result $r.row_id 'eurostat' 'failed-parse' $f.status 0 '' '' '' $out $_.Exception.Message }
  }
}

# ============================== FAMILY: eu_agrifood ==============================
$agRows = @($rows | Where-Object { $_.source_family -eq 'eu_agrifood' })
if (@($agRows).Count -gt 0) {
  Write-Host '--- family: eu_agrifood ---'
  foreach ($r in $agRows) {
    $out = Join-Path $passDir ($r.row_id + '_' + $PassLabel + '.json')
    $f = Invoke-ProbeFetch -Url $r.endpoint -Family 'eu_agrifood' -OutFile $out
    if (-not $f.ok) { Add-Result $r.row_id 'eu_agrifood' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; continue }
    try {
      $raw = Get-Content $out -Raw
      $j = $raw | ConvertFrom-Json
      $arr = $null
      if ($j -is [System.Array]) { $arr = @($j) }
      else { foreach ($p in $j.PSObject.Properties) { if ($p.Value -is [System.Array]) { $arr = @($p.Value); break } } }
      if ($null -eq $arr -or @($arr).Count -eq 0) { Add-Result $r.row_id 'eu_agrifood' 'failed-parse' $f.status 0 '' '' '' $out ('no record array; top-level: ' + (($j.PSObject.Properties.Name | Select-Object -First 8) -join ',')); continue }
      # series_code filter grammar: "prop=value;prop=value" applied client-side (v2 pinning)
      if (([string]$r.series_code) -match '=') {
        foreach ($pair in (([string]$r.series_code) -split ';')) {
          $kv = $pair -split '=', 2
          if ($kv.Count -eq 2) {
            $fp = $kv[0].Trim(); $fv = $kv[1].Trim()
            $arr = @($arr | Where-Object { ([string]$_.$fp) -eq $fv })
          }
        }
        if (@($arr).Count -eq 0) { Add-Result $r.row_id 'eu_agrifood' 'failed-parse' $f.status 0 '' '' '' $out ('no records left after pin filters: ' + $r.series_code); continue }
      }
      $propNames = @($arr[0].PSObject.Properties.Name)
      $dateProp = $null
      foreach ($cand in @('endDate', 'referenceDate', 'date', 'beginDate', 'period', 'ym')) { if ($propNames -contains $cand) { $dateProp = $cand; break } }
      $priceProp = $null
      foreach ($cand in @('price', 'averagePrice', 'avgPrice', 'value')) { if ($propNames -contains $cand) { $priceProp = $cand; break } }
      $composite = ($null -eq $dateProp -and ($propNames -contains 'year') -and ($propNames -contains 'month'))
      if (($null -eq $dateProp -and -not $composite) -or $null -eq $priceProp) { Add-Result $r.row_id 'eu_agrifood' 'failed-parse' $f.status ([int]@($arr).Count) '' '' '' $out ('props: ' + ($propNames -join ',')); continue }
      $inv = [System.Globalization.CultureInfo]::InvariantCulture
      $parsed = New-Object System.Collections.Generic.List[object]
      foreach ($rec in $arr) {
        $d = $null
        if ($composite) {
          $dt = [datetime]::MinValue
          $cand = ('{0} {1} 01' -f [string]$rec.year, [string]$rec.month)
          foreach ($fmt in @('yyyy MMMM dd', 'yyyy MMM dd')) {
            if ([datetime]::TryParseExact($cand, $fmt, $inv, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) { $d = $dt; break }
          }
        } else { $d = Parse-DateLoose ([string]$rec.$dateProp) }
        $v = Parse-PriceLoose ([string]$rec.$priceProp)
        if ($null -ne $d -and $null -ne $v) { $parsed.Add(@{ d = $d; v = [double]$v; raw = ($rec | ConvertTo-Json -Compress -Depth 3) }) }
      }
      if ($parsed.Count -eq 0) { Add-Result $r.row_id 'eu_agrifood' 'failed-parse' $f.status ([int]@($arr).Count) '' '' '' $out ('records present but no castable (date,price); props: ' + ($propNames -join ',')); continue }
      $sorted = @($parsed | Sort-Object { $_.d })
      $maxD = $sorted[$sorted.Count - 1].d
      $atMax = @($parsed | Where-Object { $_.d -eq $maxD } | Sort-Object { $_.raw })
      Add-Result $r.row_id 'eu_agrifood' 'ok' $f.status ([int]$parsed.Count) $sorted[0].d.ToString('yyyy-MM-dd') $maxD.ToString('yyyy-MM-dd') ([string]$atMax[0].v) $out ('dateProp=' + $dateProp + ';priceProp=' + $priceProp)
    } catch { Add-Result $r.row_id 'eu_agrifood' 'failed-parse' $f.status 0 '' '' '' $out $_.Exception.Message }
  }
}

# ============================== FAMILY: fao (shared asset discovery) ==============================
$faoRows = @($rows | Where-Object { $_.source_family -eq 'fao' })
if (@($faoRows).Count -gt 0) {
  Write-Host '--- family: fao (stable CSV, one shared fetch) ---'
  $faoFile = Join-Path $passDir ('FAMILY_fao_' + $PassLabel + '.csv')
  $faoUrl = [string]$faoRows[0].endpoint
  $f = Invoke-ProbeFetch -Url $faoUrl -Family 'fao' -OutFile $faoFile
  $faoOk = $false
  if ($f.ok) {
    $head = (Get-Content $faoFile -TotalCount 5) -join "`n"
    if ($head -match ',') { $faoOk = $true }
  }
  if (-not $faoOk) {
    foreach ($r in $faoRows) { Add-Result $r.row_id 'fao' 'failed-fetch' $f.status 0 '' '' '' '' ('stable CSV fetch failed: ' + $f.reason) }
  } else {
    $triage.Add('fao stable asset ok: ' + $faoUrl)
    $lines = @(Get-Content $faoFile)
    $hdrIdx = -1
    for ($i = 0; $i -lt [math]::Min(10, $lines.Count); $i++) { if ($lines[$i] -match '^Date,' ) { $hdrIdx = $i; break } }
    if ($hdrIdx -lt 0) {
      foreach ($r in $faoRows) { Add-Result $r.row_id 'fao' 'failed-parse' 200 0 '' '' '' $faoFile 'no header line starting with Date,' }
    } else {
      $hdr = $lines[$hdrIdx] -split ','
      foreach ($r in $faoRows) {
        $needle = [string]$r.series_code   # exact column name, e.g. 'Food Price Index', 'Cereals'
        $colIdx = -1
        for ($c = 1; $c -lt $hdr.Count; $c++) { if (($hdr[$c]).Trim() -eq $needle) { $colIdx = $c; break } }
        if ($colIdx -lt 0) { Add-Result $r.row_id 'fao' 'failed-parse' 200 0 '' '' '' $faoFile ('column ' + $needle + ' not found; header: ' + $lines[$hdrIdx]); continue }
        $obs = New-Object System.Collections.Generic.List[object]
        for ($i = $hdrIdx + 1; $i -lt $lines.Count; $i++) {
          $parts = $lines[$i] -split ','
          if ($parts.Count -le $colIdx) { continue }
          $v = Parse-PriceLoose $parts[$colIdx]
          if ($null -ne $v -and ([string]$parts[0]).Trim() -ne '') { $obs.Add(@{ p = ([string]$parts[0]).Trim(); v = [double]$v }) }
        }
        if ($obs.Count -eq 0) { Add-Result $r.row_id 'fao' 'failed-parse' 200 0 '' '' '' $faoFile 'no castable observations' }
        else { Add-Result $r.row_id 'fao' 'ok' 200 ([int]$obs.Count) $obs[0].p $obs[$obs.Count-1].p ([string]$obs[$obs.Count-1].v) $faoFile ('asset=' + $faoUrl) }
      }
    }
  }
}

# ============================== FAMILIES: icco / ico / mpob (asset discovery) ==============================
function Probe-PageFamily {
  param([object]$Row, [string]$Family, [string[]]$AssetRegexes)
  $out = Join-Path $passDir ($Row.row_id + '_' + $PassLabel + '_page.html')
  $f = Invoke-ProbeFetch -Url $Row.endpoint -Family $Family -OutFile $out
  if (-not $f.ok) { Add-Result $Row.row_id $Family 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; return }
  # direct asset case: endpoint itself is an xlsx/csv
  if ($Row.endpoint -match '\.(xlsx|csv)(\?|$)') {
    $ext = 'xlsx'; if ($Row.endpoint -match '\.csv') { $ext = 'csv' }
    $asset = Join-Path $passDir ($Row.row_id + '_' + $PassLabel + '.' + $ext)
    Move-Item -Force $out $asset
    Probe-GenericAsset -Row $Row -Family $Family -Path $asset -SourceUrl $Row.endpoint
    return
  }
  $html = Get-Content $out -Raw
  $found = $null
  foreach ($rx in $AssetRegexes) {
    $m = [regex]::Matches($html, $rx, 'IgnoreCase')
    if ($m.Count -gt 0) { $found = $m[0].Groups[1].Value; break }
  }
  if ($null -eq $found) { Add-Result $Row.row_id $Family 'failed-parse' $f.status 0 '' '' '' $out 'no machine-readable asset link found on page'; return }
  if ($found -notmatch '^https?://') {
    $u = [Uri]$Row.endpoint
    if ($found.StartsWith('/')) { $found = $u.Scheme + '://' + $u.Host + $found } else { $found = $u.Scheme + '://' + $u.Host + '/' + $found }
  }
  $triage.Add($Row.row_id + ' discovered asset: ' + $found)
  $ext2 = 'xlsx'; if ($found -match '\.csv') { $ext2 = 'csv' }
  $asset2 = Join-Path $passDir ($Row.row_id + '_' + $PassLabel + '.' + $ext2)
  $f2 = Invoke-ProbeFetch -Url $found -Family $Family -OutFile $asset2
  if (-not $f2.ok) { Add-Result $Row.row_id $Family 'failed-fetch' $f2.status 0 '' '' '' $out ('asset fetch failed: ' + $found); return }
  Probe-GenericAsset -Row $Row -Family $Family -Path $asset2 -SourceUrl $found
}

function Probe-GenericAsset {
  param([object]$Row, [string]$Family, [string]$Path, [string]$SourceUrl)
  try {
    $obs = New-Object System.Collections.Generic.List[object]
    if ($Path -match '\.csv$') {
      foreach ($line in (Get-Content $Path)) {
        $parts = $line -split '[,;]'
        if ($parts.Count -lt 2) { continue }
        $d = Parse-DateLoose ([string]$parts[0]).Trim('"')
        $v = $null
        for ($c = 1; $c -lt $parts.Count; $c++) { $v = Parse-PriceLoose $parts[$c]; if ($null -ne $v) { break } }
        if ($null -ne $d -and $null -ne $v) { $obs.Add(@{ d = $d; v = [double]$v }) }
      }
    } else {
      $sheet = Read-XlsxSheet -Path $Path
      foreach ($sr in $sheet) {
        if (-not $sr.Cells.ContainsKey(1)) { continue }
        $c1 = [string]$sr.Cells[1]
        $d = $null
        $serial = Parse-PriceLoose $c1
        if ($c1 -match '^\d+(\.\d+)?$' -and $null -ne $serial -and [double]$serial -gt 20000 -and [double]$serial -lt 80000) {
          $d = [datetime]::FromOADate([double]$serial)   # Excel date serial
        } else { $d = Parse-DateLoose $c1 }
        if ($null -eq $d) { continue }
        $v = $null
        foreach ($k in ($sr.Cells.Keys | Sort-Object)) { if ([int]$k -gt 1) { $v = Parse-PriceLoose ([string]$sr.Cells[$k]); if ($null -ne $v) { break } } }
        if ($null -ne $v) { $obs.Add(@{ d = $d; v = [double]$v }) }
      }
    }
    if ($obs.Count -eq 0) { Add-Result $Row.row_id $Family 'failed-parse' 200 0 '' '' '' $Path ('asset fetched but no (date,value) rows; src=' + $SourceUrl); return }
    $sorted = @($obs | Sort-Object { $_.d })
    Add-Result $Row.row_id $Family 'ok' 200 ([int]$obs.Count) $sorted[0].d.ToString('yyyy-MM-dd') $sorted[$sorted.Count-1].d.ToString('yyyy-MM-dd') ([string]$sorted[$sorted.Count-1].v) $Path ('asset=' + $SourceUrl)
  } catch { Add-Result $Row.row_id $Family 'failed-parse' 200 0 '' '' '' $Path $_.Exception.Message }
}

foreach ($r in @($rows | Where-Object { $_.source_family -eq 'icco' })) {
  Write-Host '--- family: icco ---'
  Probe-PageFamily -Row $r -Family 'icco' -AssetRegexes @('href="([^"]*daily[^"]*\.xlsx)"', 'href="([^"]*price[^"]*\.xlsx)"', 'href="([^"]*\.xlsx)"')
}
foreach ($r in @($rows | Where-Object { $_.source_family -eq 'ico' })) {
  Write-Host '--- family: ico ---'
  Probe-PageFamily -Row $r -Family 'ico' -AssetRegexes @('href="([^"]*indicator[^"]*\.xlsx)"', 'href="([^"]*price[^"]*\.(xlsx|csv))"')
}
foreach ($r in @($rows | Where-Object { $_.source_family -eq 'mpob' })) {
  Write-Host '--- family: mpob ---'
  Probe-PageFamily -Row $r -Family 'mpob' -AssetRegexes @('href="([^"]*price[^"]*\.(xlsx|csv))"', 'href="([^"]*\.csv)"')
}

# ============================== FAMILY: usda ==============================
$usdaRows = @($rows | Where-Object { $_.source_family -eq 'usda' })
if (@($usdaRows).Count -gt 0) {
  Write-Host '--- family: usda ---'
  foreach ($r in $usdaRows) {
    if ([string]::IsNullOrEmpty($usdaKey)) { Add-Result $r.row_id 'usda' 'blocked-no-key' 0 0 '' '' '' '' 'USDA_FAS_KEY absent (env/.env)'; continue }
    $out = Join-Path $passDir ($r.row_id + '_' + $PassLabel + '.json')
    $f = Invoke-ProbeFetch -Url $r.endpoint -Family 'usda' -OutFile $out -Headers @{ 'API_KEY' = $usdaKey }
    if (-not $f.ok) { Add-Result $r.row_id 'usda' 'failed-fetch' $f.status 0 '' '' '' '' $f.reason; continue }
    try {
      $j = (Get-Content $out -Raw) | ConvertFrom-Json
      $arr = @($j)
      $codeParts = ([string]$r.series_code) -split '#'
      $attrNeedle = $codeParts[1]; $ctryNeedle = $codeParts[2]
      $hits = @($arr | Where-Object { ([string]$_.AttributeDescription) -match $attrNeedle -and ([string]$_.CountryName) -match $ctryNeedle })
      if (@($hits).Count -eq 0) { Add-Result $r.row_id 'usda' 'failed-parse' $f.status ([int]@($arr).Count) '' '' '' $out ('no record matching attr=' + $attrNeedle + ' country=' + $ctryNeedle); continue }
      $h = $hits[0]
      Add-Result $r.row_id 'usda' 'ok' $f.status ([int]@($hits).Count) ([string]$h.MarketYear) ([string]$h.MarketYear) ([string]([double]$h.Value)) $out 'PSD current-MY projection'
    } catch { Add-Result $r.row_id 'usda' 'failed-parse' $f.status 0 '' '' '' $out $_.Exception.Message }
  }
}

# ============================== licensed rows: never fetched ==============================
foreach ($r in @($rows | Where-Object { $_.access -eq 'licensed-upload' })) {
  Add-Result $r.row_id 'licensed_upload' 'skipped-licensed' 0 0 '' '' '' '' 'lane validated against real workbook only'
}

# ============================== control fetch if anything failed ==============================
$anyFail = @($results | Where-Object { $_.outcome -eq 'failed-fetch' })
if (@($anyFail).Count -gt 0) {
  $ctrlOut = Join-Path $passDir ('CONTROL_' + $PassLabel + '.json')
  $cf = Invoke-ProbeFetch -Url 'https://api.worldbank.org/v2/country/DEU?format=json' -Family 'control' -OutFile $ctrlOut
  $cs = 'control fetch FAILED - failures may be pipeline-side, not endpoint-side'
  if ($cf.ok) { $cs = 'control fetch ok - failures attributable to endpoints (ONS-Revolut pattern)' }
  Add-Result 'CONTROL' 'control' ($(if ($cf.ok) { 'ok' } else { 'failed-fetch' })) $cf.status 0 '' '' '' $ctrlOut $cs
}

# ============================== emit ==============================
$resultsPath = Join-Path $probeRoot ('probe_results_' + $PassLabel + '.csv')
$results | Export-Csv -Path $resultsPath -NoTypeInformation -Encoding UTF8
if ($triage.Count -gt 0) { $triage | Set-Content -Path (Join-Path $passDir 'triage_notes.txt') -Encoding UTF8 }

Write-Host ''
Write-Host ("=== probe pass {0} summary ===" -f $PassLabel)
foreach ($g in ($results | Group-Object outcome | Sort-Object Name)) { Write-Host ("  {0} = {1}" -f $g.Name, [int]$g.Count) }
Write-Host ("results: {0}" -f $resultsPath)
