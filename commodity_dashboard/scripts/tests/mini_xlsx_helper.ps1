# mini_xlsx_helper.ps1 — TEST-ONLY minimal .xlsx writer (inlineStr cells, one sheet).
# Used by test_licensed_contract.ps1 rejection fixtures. Never part of the data pipeline.

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
Add-Type -AssemblyName System.IO.Compression | Out-Null

function New-MiniXlsx {
  param([string]$Path, [string]$SheetName, [object[]]$Rows)
  if (Test-Path $Path) { Remove-Item -Force $Path }
  $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    $enc = New-Object System.Text.UTF8Encoding($false)
    $add = {
      param($name, $content)
      $e = $zip.CreateEntry($name)
      $sw = New-Object System.IO.StreamWriter($e.Open(), $enc)
      try { $sw.Write($content) } finally { $sw.Dispose() }
    }
    & $add '[Content_Types].xml' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'
    & $add '_rels/.rels' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'
    & $add 'xl/workbook.xml' ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="' + $SheetName + '" sheetId="1" r:id="rId1"/></sheets></workbook>')
    & $add 'xl/_rels/workbook.xml.rels' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>')
    $rowNum = 0
    foreach ($row in $Rows) {
      $rowNum++
      [void]$sb.Append('<row r="' + $rowNum + '">')
      $colNum = 0
      foreach ($cell in @($row)) {
        $colNum++
        $colLetter = [char](64 + $colNum)
        [void]$sb.Append('<c r="' + $colLetter + $rowNum + '" t="inlineStr"><is><t>' + $cell + '</t></is></c>')
      }
      [void]$sb.Append('</row>')
    }
    [void]$sb.Append('</sheetData></worksheet>')
    & $add 'xl/worksheets/sheet1.xml' $sb.ToString()
  } finally { $zip.Dispose() }
}
