# UFO File Downloader

`DownloadUFOFiles.ps1` downloads UFO files listed in the war.gov UFO CSV and organizes them into per-record folders.

## What it does

The script:

- Downloads or reuses the UFO CSV.
- Reads each CSV row and creates a numbered folder for that record.
- Writes all CSV fields for the record to `info.txt`.
- Extracts linked files from CSV values.
- Downloads each linked file into the record folder.
- Prints record and file download progress to the console.
- Logs failed downloads without stopping the whole run.

## Recommended usage

If you already have the CSV locally:

```powershell
.\DownloadUFOFiles.ps1 -PrimeSession -CsvPath '.\uap-files\uap-csv.csv'
```

If you want the script to download the CSV first:

```powershell
.\DownloadUFOFiles.ps1 -PrimeSession
```

`-PrimeSession` visits `https://www.war.gov/UFO/` before downloading files. Any cookies issued by that page are reused by the same `WebRequestSession` for the CSV and file downloads.

## Output

By default, files are written to:

```text
.\DownloadUFOFiles
```

Each CSV record gets a folder like:

```text
001-65_HS1-834228961_62-HQ-83894_Section_10
```

Each folder contains:

- `info.txt` with the CSV metadata.
- Downloaded files such as `.pdf` and `.jpg`.
- `download-errors.txt` if any linked downloads failed.
- `.url` files for failed links.

## Options

| Parameter | Description |
| --- | --- |
| `-CsvUrl` | Source CSV URL. Defaults to the war.gov UFO CSV. |
| `-CsvPath` | Use an existing local CSV instead of downloading one. |
| `-OutputPath` | Output folder. Defaults to `DownloadUFOFiles`. |
| `-PrimeSession` | Visit the UFO landing page first and reuse server-issued cookies. |
| `-PrimeUri` | Landing page URLs to try when priming the session. |
| `-UserAgent` | Browser-like user agent used for requests. |
| `-Referer` | Referer header used for requests. |

## Notes

This script works with the current war.gov UFO page and CSV layout. It depends on the CSV staying available and continuing to contain the file links in a compatible format, so there is no guarantee it will keep working if the site structure, CSV schema, URLs, or server-side download behavior changes.

The script does not bypass server-side access controls. If a specific file is blocked or missing, the failure is logged and the rest of the CSV continues processing.
