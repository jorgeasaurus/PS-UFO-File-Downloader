<#
  Download UFO files from war.gov.

  Recommended first run:
    .\DownloadUFOFiles.ps1 -PrimeSession -CsvPath '.\uap-files\uap-csv.csv'

  -PrimeSession visits https://www.war.gov/UFO/ first and reuses any cookies
  issued by the server for the file downloads. This avoids manually copying
  cookies when the site allows a normal scripted landing-page request.

  If the CSV is not already available locally, omit -CsvPath:
    .\DownloadUFOFiles.ps1 -PrimeSession

  Files are written under -OutputPath, defaulting to .\DownloadUFOFiles.
  Existing local CSV files are reused. Failed links produce download-errors.txt
  and a .url file beside the item metadata.

  Examples:
  .\DownloadUFOFiles.ps1 `
    -CsvPath '.\uap-files\uap-csv.csv' `
    -OutputPath '.\DownloadUFOFiles' `
    -PrimeSession `
    -Verbose
#>
[CmdletBinding()]
param(
  [string]$CsvUrl = 'https://www.war.gov/Portals/1/Interactive/2026/UFO/uap-csv.csv',

  [string]$OutputPath = 'DownloadUFOFiles',

  [string]$CsvPath,

  [string]$UserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',

  [string]$Referer = 'https://www.war.gov/UFO/',

  [switch]$PrimeSession,

  [string[]]$PrimeUri = @('https://www.war.gov/UFO/', 'https://www.war.gov/')
)

$ProgressPreference = 'SilentlyContinue'

function Invoke-UfoRequest {
  param(
    [Parameter(Mandatory)]
    [uri]$Uri,

    [Parameter(Mandatory)]
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

    [Parameter(Mandatory)]
    [hashtable]$Headers,

    [string]$OutFile
  )

  $params = @{
    Uri         = $Uri
    WebSession  = $Session
    Headers     = $Headers
    ErrorAction = 'Stop'
  }

  if ($OutFile) {
    $params.OutFile = $OutFile
  }

  if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $params.UseBasicParsing = $true
  }

  Invoke-WebRequest @params
}

$baseUri = [uri]$CsvUrl
$session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$session.UserAgent = $UserAgent

$headers = @{
  Accept                    = 'text/html,application/xhtml+xml,application/xml;q=0.9,application/pdf,image/avif,image/webp,image/apng,image/*,*/*;q=0.8'
  'Accept-Language'         = 'en-US,en;q=0.9'
  'Cache-Control'           = 'max-age=0'
  Referer                   = $Referer
  'Sec-Fetch-Dest'          = 'document'
  'Sec-Fetch-Mode'          = 'navigate'
  'Sec-Fetch-Site'          = 'same-origin'
  'Upgrade-Insecure-Requests' = '1'
}

if ($PrimeSession) {
  foreach ($uriText in $PrimeUri) {
    try {
      Invoke-UfoRequest -Uri ([uri]$uriText) -Session $session -Headers $headers | Out-Null
      Write-Verbose "Primed session with $uriText"
      break
    }
    catch {
      Write-Warning ("Session prime failed for {0}: {1}" -f $uriText, $_.Exception.Message)
    }
  }
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$csvFile = if ($CsvPath) {
  $CsvPath
}
else {
  Join-Path $OutputPath 'uap-csv.csv'
}

if (-not (Test-Path -LiteralPath $csvFile)) {
  Write-Host "Downloading CSV: $CsvUrl"
  Invoke-UfoRequest -Uri $baseUri -Session $session -Headers $headers -OutFile $csvFile
}
else {
  Write-Host "Using CSV: $csvFile"
}

$records = @(Import-Csv -LiteralPath $csvFile)
$totalRecords = $records.Count
$downloadedCount = 0
$failedCount = 0
$i = 0

Write-Host "Processing $totalRecords records..."

foreach ($record in $records) {
  $i++
  $title = ($record.Title -replace '\s+', ' ').Trim()
  if (-not $title) { $title = "Item-$i" }
  $safeTitle = ($title -replace '[\\/:*?"<>|]+', '-' -replace '\s+', '_').Trim(' ._-')
  if ($safeTitle.Length -gt 80) { $safeTitle = $safeTitle.Substring(0, 80).Trim(' ._-') }

  $dir = Join-Path $OutputPath ('{0:000}-{1}' -f $i, $safeTitle)
  New-Item -ItemType Directory -Path $dir -Force | Out-Null

  $record.PSObject.Properties |
    ForEach-Object { '{0}: {1}' -f $_.Name, ($_.Value -replace '\s+', ' ').Trim() } |
    Set-Content -LiteralPath (Join-Path $dir 'info.txt')

  $links = $record.PSObject.Properties.Value |
    Select-String -Pattern 'https?://\S+|/Portals/\S+|/medialink/\S+' -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    ForEach-Object { ([uri]::new($baseUri, $_.TrimEnd('.,);]'))).AbsoluteUri } |
    Sort-Object -Unique

  Write-Host ("[{0}/{1}] {2} ({3} link(s))" -f $i, $totalRecords, $title, $links.Count)

  $n = 0
  foreach ($link in $links) {
    $n++
    $linkUri = [uri]$link

    $name = [uri]::UnescapeDataString($linkUri.Segments[-1])
    if (-not $name) { $name = "linked-file-$n" }
    $name = $name -replace '[\\/:*?"<>|]+', '-'
    $file = Join-Path $dir $name
    if (Test-Path -LiteralPath $file) {
      $file = Join-Path $dir ('{0}-{1}' -f $n, $name)
    }

    try {
      Write-Host ("  [{0}/{1}] Downloading {2}" -f $n, $links.Count, $name)
      Invoke-UfoRequest -Uri $linkUri -Session $session -Headers $headers -OutFile $file
      $downloadedCount++
    }
    catch {
      if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
      'FAILED: {0}' -f $link | Add-Content -LiteralPath (Join-Path $dir 'download-errors.txt')
      'ERROR:  {0}' -f $_.Exception.Message | Add-Content -LiteralPath (Join-Path $dir 'download-errors.txt')
      'URL:    {0}' -f $link | Set-Content -LiteralPath (Join-Path $dir ("$name.url"))
      $failedCount++
      Write-Warning ("  [{0}/{1}] Failed {2}: {3}" -f $n, $links.Count, $name, $_.Exception.Message)
    }
  }
}

Write-Host ("Done. Records: {0}; downloaded: {1}; failed: {2}; output: {3}" -f $totalRecords, $downloadedCount, $failedCount, $OutputPath)
