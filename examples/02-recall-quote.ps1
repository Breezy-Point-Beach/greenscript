# 02-recall-quote.ps1 - navigate to WAQ, recall a quote by number, print the
# Quote Worksheet that results.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the Apache License, Version 2.0
#
# This script sends keystrokes. The approval gate on Send-GsKeys is active, so
# every send prompts unless you pass -Confirm:$false. Nothing destructive is
# attempted; the script does not save, post, or create records.
#
# Example:
#   .\examples\02-recall-quote.ps1 -QuoteNumber 490627
#   .\examples\02-recall-quote.ps1 -QuoteNumber 490627 -Confirm:$false  # scripted

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,10}$')]
    [string] $QuoteNumber,

    [int] $Rows = 24,
    [int] $Cols = 80,

    [int] $TimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\powershell\GreenScript.psd1') -Force

$session = Connect-GsSession -Rows $Rows -Cols $Cols
try {
    # Navigate to Work a Quote. If we are already there, WAQ<Enter> is a
    # no-op from the command prompt; most other screens accept it as well.
    Send-GsKeys -Session $session -Keys 'WAQ<Enter>'
    $landed = Wait-GsText -Session $session -Text 'Work a Quote' -Row 1 -Col 1 -TimeoutSeconds $TimeoutSeconds
    if (-not $landed.Found) {
        throw ("WAQ screen did not appear within {0}s. Check the current screen." -f $TimeoutSeconds)
    }

    # Type the quote number into the Recall/Find box and press Enter.
    Send-GsKeys -Session $session -Keys ("{0}<Enter>" -f $QuoteNumber)
    # Quote Worksheet shows 'Quote' at the top left of the detail view.
    $loaded = Wait-GsText -Session $session -Text 'Quote' -Row 1 -Col 1 -TimeoutSeconds $TimeoutSeconds
    if (-not $loaded.Found) {
        Write-Warning ("Quote detail did not appear within {0}s - the number may not exist." -f $TimeoutSeconds)
    }

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
