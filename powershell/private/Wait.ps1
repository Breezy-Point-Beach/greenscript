# Wait.ps1 - Wait-GsText.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# Thin wrapper over BZWhll.WaitForText that returns a structured result
# instead of a raw status code.

function Wait-GsText {
    <#
    .SYNOPSIS
    Wait for a text string to appear at a given screen position.

    .DESCRIPTION
    Returns a result object with Found ($true if the text appeared before the
    timeout), StatusCode (BlueZone's raw return: 0 found, 4 timeout, other
    error), and DurationMs. Does not throw on timeout; inspect Found.

    .PARAMETER Session
    The session handle returned by Connect-GsSession.

    .PARAMETER Text
    The text to wait for. Matched by BlueZone at the exact (Row, Col) start.

    .PARAMETER Row
    1-based row to check.

    .PARAMETER Col
    1-based column to check.

    .PARAMETER TimeoutSeconds
    How long to wait before giving up. Default 10.

    .EXAMPLE
    $r = Wait-GsText -Session $s -Text 'Work a Quote' -Row 1 -Col 1 -TimeoutSeconds 10
    if (-not $r.Found) { throw 'WAQ screen did not appear.' }

    .OUTPUTS
    pscustomobject with Found, StatusCode, DurationMs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Session,
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [ValidateRange(1, 100)] [int] $Row,
        [Parameter(Mandatory)] [ValidateRange(1, 500)] [int] $Col,
        [ValidateRange(1, 3600)] [int] $TimeoutSeconds = 10
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $code = $Session.Interop.WaitForText($Text, $Row, $Col, $TimeoutSeconds)
        $sw.Stop()
        $found = ($code -eq 0)
        $result = [pscustomobject]@{
            Found       = $found
            StatusCode  = [int]$code
            DurationMs  = [int]$sw.ElapsedMilliseconds
        }
        Write-GsAudit -Session $Session -Action 'wait' `
            -Args @{ text = $Text; row = $Row; col = $Col; timeoutSeconds = $TimeoutSeconds } `
            -Result @{ found = $found; statusCode = $code } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true
        return $result
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'wait' `
            -Args @{ text = $Text; row = $Row; col = $Col; timeoutSeconds = $TimeoutSeconds } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}
