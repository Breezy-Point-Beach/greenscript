# 03-sales-tax-upload.ps1 - pattern for bulk data entry: iterate over a CSV
# and type each row into a form, with per-row approval.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# This script is a template. It does not assume a specific host form layout;
# it shows the greenscript idioms for safe bulk entry:
#   - open the target screen and wait for a known header
#   - for each row, type field by field, press Tab or Enter between
#   - per-row approval; -Unattended disables it (not recommended for a first run)
#   - -DryRun prints and audits what would be sent without sending
#   - every keystroke is audited to JSONL
#
# CSV format expected (adapt as needed):
#   Jurisdiction,Rate,EffectiveDate
#   CA-LA-COUNTY,0.0975,2026-10-01
#   CA-SF-COUNTY,0.0875,2026-10-01
#
# Example:
#   .\examples\03-sales-tax-upload.ps1 -Csv .\rates.csv -DryRun
#   .\examples\03-sales-tax-upload.ps1 -Csv .\rates.csv -ScreenCode 'TAX'
#   .\examples\03-sales-tax-upload.ps1 -Csv .\rates.csv -ScreenCode 'TAX' -Unattended

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Csv,

    # Screen navigation code: adapt to the form your host uses.
    [string] $ScreenCode = 'TAX',

    # Expected header on the target screen and where it appears.
    [string] $ScreenHeader = 'Tax Rate Maintenance',
    [int]    $HeaderRow    = 1,
    [int]    $HeaderCol    = 1,

    [int] $Rows = 24,
    [int] $Cols = 80,
    [int] $TimeoutSeconds = 10,

    # Print the keystrokes that would be sent and audit them, but do not
    # call Send-GsKeys. Useful for a first-pass review of the CSV.
    [switch] $DryRun,

    # Skip the per-row confirmation prompt. The forbidden-key prompt in
    # Send-GsKeys still applies.
    [switch] $Unattended
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\powershell\GreenScript.psd1') -Force

# -Confirm:$false set on this script does not propagate into module cmdlets
# on PowerShell 5.1, so the switch is passed through explicitly.
$confirm = -not $Unattended

$rows = @(Import-Csv -LiteralPath $Csv)
if ($rows.Count -eq 0) { throw "CSV is empty: $Csv" }
Write-Host ("Loaded {0} rows from {1}" -f $rows.Count, $Csv)

$session = Connect-GsSession -Rows $Rows -Cols $Cols
try {
    Send-GsKeys -Session $session -Keys ("{0}<Enter>" -f $ScreenCode) -Confirm:$confirm
    $r = Wait-GsText -Session $session -Text $ScreenHeader -Row $HeaderRow -Col $HeaderCol -TimeoutSeconds $TimeoutSeconds
    if (-not $r.Found) {
        throw ("'{0}' did not appear at row {1} col {2}. Check -ScreenCode / -ScreenHeader / -HeaderRow / -HeaderCol." -f $ScreenHeader, $HeaderRow, $HeaderCol)
    }

    $i = 0
    foreach ($row in $rows) {
        $i++
        $jur  = $row.Jurisdiction
        $rate = $row.Rate
        $eff  = $row.EffectiveDate

        $keys  = ("{0}<Tab>{1}<Tab>{2}<Enter>" -f $jur, $rate, $eff)
        $label = ("row {0}/{1}  {2}  {3}  {4}" -f $i, $rows.Count, $jur, $rate, $eff)

        if ($DryRun) {
            Write-Host ("[DRY-RUN] {0}  ->  {1}" -f $label, $keys)
            Write-GsAudit -Session $session -Action 'dryrun' `
                -Arguments @{ row = $i; jurisdiction = $jur; rate = $rate; effectiveDate = $eff; keys = $keys } `
                -Result @{ sent = $false; reason = 'dry-run' } `
                -DurationMs 0 -Ok $true
            continue
        }

        Write-Host ("Sending {0}" -f $label)
        Send-GsKeys -Session $session -Keys $keys -Confirm:$confirm

        # Give the host a moment to accept the row before the next one.
        $null = Wait-GsText -Session $session -Text $ScreenHeader -Row $HeaderRow -Col $HeaderCol -TimeoutSeconds 3
    }

    Write-Host ('-' * 80)
    Write-Host ("Done. {0} rows processed. Audit: {1}" -f $rows.Count, (Get-GsAuditPath))
}
finally {
    Disconnect-GsSession $session
}
