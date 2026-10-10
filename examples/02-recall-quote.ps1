# 02-recall-quote.ps1 - navigate to a quote-lookup screen, recall a quote by
# number, print the worksheet that results.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# This script sends keystrokes. The approval gate on Send-GsKeys is active, so
# every send prompts unless you pass -Unattended. Nothing destructive is
# attempted; the script does not save, post, or create records.
#
# The navigation code ('WAQ'), the header text waited for, and the row/column
# positions are host-specific. They are set for a common dealer DMS layout as
# an illustration; adapt them to your own screens.
#
# Example:
#   .\examples\02-recall-quote.ps1 -QuoteNumber 490627
#   .\examples\02-recall-quote.ps1 -QuoteNumber 490627 -Unattended   # scripted

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,10}$')]
    [string] $QuoteNumber,

    [string] $ScreenCode   = 'WAQ',
    [string] $ScreenHeader = 'Work a Quote',
    [int]    $HeaderRow    = 1,
    [int]    $HeaderCol    = 1,

    [int] $Rows = 24,
    [int] $Cols = 80,
    [int] $TimeoutSeconds = 10,

    # Skip the per-send confirmation prompt. The forbidden-key prompt in
    # Send-GsKeys still applies (none of the keys below trigger it).
    [switch] $Unattended
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\powershell\GreenScript.psd1') -Force

# -Confirm:$false set on this script does not propagate into module cmdlets
# on PowerShell 5.1, so the switch is passed through explicitly.
$confirm = -not $Unattended

$session = Connect-GsSession -Rows $Rows -Cols $Cols
try {
    Send-GsKeys -Session $session -Keys ("{0}<Enter>" -f $ScreenCode) -Confirm:$confirm
    $landed = Wait-GsText -Session $session -Text $ScreenHeader -Row $HeaderRow -Col $HeaderCol -TimeoutSeconds $TimeoutSeconds
    if (-not $landed.Found) {
        throw ("'{0}' did not appear at row {1} col {2} within {3}s. Check -ScreenHeader / -HeaderRow / -HeaderCol." -f $ScreenHeader, $HeaderRow, $HeaderCol, $TimeoutSeconds)
    }

    Send-GsKeys -Session $session -Keys ("{0}<Enter>" -f $QuoteNumber) -Confirm:$confirm
    # Give the host a moment to redraw before reading.
    $null = Wait-GsText -Session $session -Text $ScreenHeader -Row $HeaderRow -Col $HeaderCol -TimeoutSeconds 3

    Write-Host ('-' * 80)
    Read-GsScreen -Session $session |
        ForEach-Object { "{0,2}  {1}" -f $_.Row, $_.Text } |
        Write-Host
    Write-Host ('-' * 80)
    Write-Host ("Quote {0} - read-only. No save, no post. Audit: {1}" -f $QuoteNumber, (Get-GsAuditPath))
}
finally {
    Disconnect-GsSession $session
}
