# 03-sales-tax-upload.ps1 - pattern for bulk data entry: iterate over a CSV
# and type each row into a form, with per-row approval.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# This script is a template. It does NOT assume a specific CDK tax-rate form
# layout; it shows the greenscript idioms for safe bulk entry:
#   - open the target screen and wait for a known header
#   - for each row, type field by field, press Tab or Enter between
#   - per-row approval; -Confirm:$false disables (not recommended for first run)
#   - every keystroke is audited to JSONL
#
# CSV format expected (adapt as needed):
#   Jurisdiction,Rate,EffectiveDate
#   CA-LA-COUNTY,0.0975,2026-10-01
#   CA-SF-COUNTY,0.0875,2026-10-01
#
# Example:
#   .\examples\03-sales-tax-upload.ps1 -Csv .\rates.csv -DryRun
#   .\examples\03-sales-tax-upload.ps1 -Csv .\rates.csv -ScreenCode 'TAX' -Confirm

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Csv,

    # Screen navigation code: adapt to the form your DMS uses.
    [string] $ScreenCode = 'TAX',

    # Expected header on the target screen; used by Wait-GsText.
    [string] $ScreenHeader = 'Tax Rate Maintenance',

    [int] $Rows = 24,
    [int] $Cols = 80,
    [int] $TimeoutSeconds = 10,

    # When set, prints the keystrokes that would be sent and audits them,
    # but does not call Send-GsKeys. Useful for a first-pass review.
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\powershell\GreenScript.psd1') -Force

$rows = Import-Csv -LiteralPath $Csv
if (-not $rows -or $rows.Count -eq 0) { throw "CSV is empty: $Csv" }
Write-Host ("Loaded {0} rows from {1}" -f $rows.Count, $Csv)

$session = Connect-GsSession -Rows $Rows -Cols $Cols
try {
    # Open the target screen.
    Send-GsKeys -Session $session -Keys ("{0}<Enter>" -f $ScreenCode)
    $r = Wait-GsText -Session $session -Text $ScreenHeader -Row 1 -Col 1 -TimeoutSeconds $TimeoutSeconds
    if (-not $r.Found) {
        throw ("Target screen '{0}' did not appear. Check -ScreenCode / -ScreenHeader." -f $ScreenHeader)
    }

    $i = 0
    foreach ($row in $rows) {
        $i++
        $jur = $row.Jurisdiction
        $rate = $row.Rate
        $eff = $row.EffectiveDate

        $keys = ("{0}<Tab>{1}<Tab>{2}<Enter>" -f $jur, $rate, $eff)
        $label = ("row {0}/{1}  {2}  {3}  {4}" -f $i, $rows.Count, $jur, $rate, $eff)

        if ($DryRun) {
            Write-Host ("[DRY-RUN] {0}  ->  {1}" -f $label, $keys)
            Write-GsAudit -Session $session -Action 'dryrun' `
                -Args @{ row = $i; jurisdiction = $jur; rate = $rate; effectiveDate = $eff; keys = $keys } `
                -Result @{ sent = $false; reason = 'dry-run' } `
                -DurationMs 0 -Ok $true
            continue
        }

        Write-Host ("Sending {0}" -f $label)
        Send-GsKeys -Session $session -Keys $keys

        # Give the host a moment to accept the row before the next one.
        $null = Wait-GsText -Session $session -Text $ScreenHeader -Row 1 -Col 1 -TimeoutSeconds 3
    }

    Write-Host ('-' * 80)
    Write-Host ("Done. {0} rows processed. Audit: {1}" -f $rows.Count, (Get-GsAuditPath))
}
finally {
    Disconnect-GsSession $session
}
