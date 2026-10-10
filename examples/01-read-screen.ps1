# 01-read-screen.ps1 - connect, read all rows, print them, release.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the Apache License, Version 2.0
#
# Minimum viable use of greenscript. Nothing is sent to the host; this script
# is strictly read-only.

[CmdletBinding()]
param(
    [int] $Rows = 24,
    [int] $Cols = 80
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\powershell\GreenScript.psd1') -Force

$session = Connect-GsSession -Rows $Rows -Cols $Cols
try {
    $cursor = Get-GsCursor -Session $session
    Write-Host ("Session {0} - cursor at row {1}, col {2}" -f $session.Tag, $cursor.Row, $cursor.Col)
    Write-Host ('-' * 80)

    Read-GsScreen -Session $session |
        ForEach-Object { "{0,2}  {1}" -f $_.Row, $_.Text } |
        Write-Host

    Write-Host ('-' * 80)
    Write-Host ("Audit log: {0}" -f (Get-GsAuditPath))
}
finally {
    Disconnect-GsSession $session
}
