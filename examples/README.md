# greenscript examples

Three self-contained scripts that exercise the connector without any AI. Each
one is runnable from a 32-bit PowerShell host with an active BlueZone session.

| Script                      | What it shows                                        |
|-----------------------------|------------------------------------------------------|
| `01-read-screen.ps1`        | Attach, read all rows, print them, release.          |
| `02-recall-quote.ps1`       | Navigate from any screen to WAQ, recall a quote by  |
|                             | number, read the resulting Quote Worksheet.          |
| `03-sales-tax-upload.ps1`   | Pattern for bulk data entry: iterate over rows in a |
|                             | CSV, type each row into a form with per-row approval.|

## Running

```powershell
# From the greenscript repo root, in 32-bit PowerShell:
Import-Module .\powershell\GreenScript.psd1 -Force
.\examples\01-read-screen.ps1
```

Or without importing globally:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\examples\01-read-screen.ps1
```

## Safety

All example scripts attach to the **active** BlueZone session. Make sure the
session you want to drive is the one in front. The `03-sales-tax-upload.ps1`
example sends keystrokes; it uses `-Confirm` by default so every row prompts.
Pass `-Confirm:$false` only after you have reviewed the CSV and understand
what will land in the host.
