# xlsx_helpers.ps1 — minimal OpenXML .xlsx reader, pure .NET (no Excel COM; CI-safe).
# Shared by probe_endpoints.ps1, capture_all.ps1 and ingest_licensed_uploads.ps1.
# Windows PowerShell 5.1 compatible.

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

function ConvertTo-ColumnIndex([string]$cellRef) {
  # 'BC12' -> column index (1-based) 55
  $letters = ($cellRef -replace '\d', '')
  $idx = 0
  foreach ($ch in $letters.ToUpperInvariant().ToCharArray()) {
    $idx = $idx * 26 + ([int][char]$ch - 64)
  }
  return [int]$idx
}

function Read-XlsxSheet {
  <#
    Returns a List of hashtables, one per spreadsheet row:
      @{ RowIndex = [int]; Cells = @{ [int]colIndex = [string]value } }
    Shared strings and inline strings resolved; numeric cells returned as raw strings
    (caller casts [double] explicitly — casting discipline).
    -SheetName: exact sheet name; if omitted, the first sheet.
  #>
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$SheetName = ''
  )
  if (-not (Test-Path $Path)) { throw "xlsx not found: $Path" }
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    function Read-Entry([object]$z, [string]$name) {
      $e = $z.GetEntry($name)
      if ($null -eq $e) { return $null }
      $sr = New-Object System.IO.StreamReader($e.Open())
      try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
    }

    # sheet name -> target path via workbook.xml + rels
    $wbXml = [xml](Read-Entry $zip 'xl/workbook.xml')
    $relXml = [xml](Read-Entry $zip 'xl/_rels/workbook.xml.rels')
    $relMap = @{}
    foreach ($rel in $relXml.Relationships.Relationship) {
      $t = [string]$rel.Target
      if ($t.StartsWith('/')) { $t = $t.TrimStart('/') } else { $t = 'xl/' + $t }
      $relMap[[string]$rel.Id] = ($t -replace 'xl/xl/', 'xl/')
    }
    $target = $null
    $sheetNames = New-Object System.Collections.Generic.List[string]
    foreach ($sh in $wbXml.workbook.sheets.sheet) {
      $sheetNames.Add([string]$sh.name)
      $rid = $sh.GetAttribute('r:id'); if ([string]::IsNullOrEmpty($rid)) { $rid = [string]$sh.id }
      if ($SheetName -eq '' -and $null -eq $target) { $target = $relMap[$rid] }
      if ($SheetName -ne '' -and [string]$sh.name -eq $SheetName) { $target = $relMap[$rid] }
    }
    if ($null -eq $target) {
      throw ("sheet '{0}' not found; available: {1}" -f $SheetName, ($sheetNames -join ', '))
    }

    # shared strings (handle plain <t> and rich-text <r><t> runs)
    $shared = New-Object System.Collections.Generic.List[string]
    $ssRaw = Read-Entry $zip 'xl/sharedStrings.xml'
    if ($null -ne $ssRaw) {
      $ssXml = [xml]$ssRaw
      foreach ($si in $ssXml.sst.si) {
        $txt = ''
        if ($null -ne $si.t) {
          if ($si.t -is [System.Xml.XmlElement]) { $txt = [string]$si.t.'#text' } else { $txt = [string]$si.t }
        } elseif ($null -ne $si.r) {
          foreach ($run in $si.r) {
            if ($run.t -is [System.Xml.XmlElement]) { $txt += [string]$run.t.'#text' } else { $txt += [string]$run.t }
          }
        }
        $shared.Add($txt)
      }
    }

    $sheetXml = [xml](Read-Entry $zip $target)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $sheetXml.worksheet.sheetData.row) {
      $cells = @{}
      foreach ($c in $row.c) {
        if ($null -eq $c) { continue }
        $ref = [string]$c.r
        if ($ref -eq '') { continue }
        $colIdx = ConvertTo-ColumnIndex $ref
        $type = [string]$c.t
        $val = ''
        if ($type -eq 'inlineStr') {
          if ($null -ne $c.is -and $null -ne $c.is.t) { $val = [string]$c.is.t }
        } else {
          $vNode = $c.v
          if ($null -ne $vNode) {
            if ($vNode -is [System.Xml.XmlElement]) { $val = [string]$vNode.'#text' } else { $val = [string]$vNode }
            if ($type -eq 's') {
              $si = -1
              if ([int]::TryParse($val, [ref]$si) -and $si -ge 0 -and $si -lt $shared.Count) { $val = $shared[$si] }
            }
          }
        }
        $cells[$colIdx] = $val
      }
      $rows.Add(@{ RowIndex = [int]$row.r; Cells = $cells })
    }
    return ,$rows
  }
  finally { $zip.Dispose() }
}

function Get-XlsxSheetNames {
  param([Parameter(Mandatory = $true)][string]$Path)
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $e = $zip.GetEntry('xl/workbook.xml')
    $sr = New-Object System.IO.StreamReader($e.Open())
    try { $wbXml = [xml]$sr.ReadToEnd() } finally { $sr.Dispose() }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($sh in $wbXml.workbook.sheets.sheet) { $names.Add([string]$sh.name) }
    return ,$names
  }
  finally { $zip.Dispose() }
}
