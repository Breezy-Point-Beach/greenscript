# Screen.ps1 - Read-GsScreen and Get-GsCursor.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# Read-GsScreen returns the full terminal buffer as an array of row objects.
# Each row has Row (1-based), Col (1 by default), Length (session Cols by
# default), and Text (the characters at that position). Partial reads are
# supported by passing -Row / -Col / -Length.
#
# Get-GsCursor returns a two-field object with Row and Col.

function Read-GsScreen {
    <#
    .SYNOPSIS
    Read the terminal screen (or a slice of it) and return rows.

    .DESCRIPTION
    By default returns Session.Rows rows, each the full session width. Pass
    -Row to read a single row, -Col and -Length to read a partial row.

    .PARAMETER Session
    The session handle returned by Connect-GsSession.

    .PARAMETER Row
    1-based row to read. 0 (the default) reads every row.

    .PARAMETER Col
    1-based starting column. Default 1.

    .PARAMETER Length
    Number of characters to read. 0 (the default) reads to the end of the row.

    .EXAMPLE
    Read-GsScreen -Session $s | Format-Table Row, Text

    .EXAMPLE
    Read-GsScreen -Session $s -Row 1 -Col 20 -Length 40

    .OUTPUTS
    An array of pscustomobject with properties Row, Col, Length, Text.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Session,
        [ValidateRange(0, 100)] [int] $Row = 0,
        [ValidateRange(1, 500)] [int] $Col = 1,
        [ValidateRange(0, 500)] [int] $Length = 0
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $rowList = if ($Row) { @($Row) } else { 1..$Session.Rows }
        $results = foreach ($r in $rowList) {
            $len = if ($Length) { [int]$Length } else { [int]$Session.Cols - ($Col - 1) }
            if ($len -lt 1) { $len = 1 }
            $text = $Session.Interop.ReadScreen($len, $r, $Col)
            [pscustomobject]@{
                Row    = $r
                Col    = $Col
                Length = $len
                Text   = $text
            }
        }
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'read' `
            -Arguments @{ row = $Row; col = $Col; length = $Length; rows = $rowList.Count } `
            -Result @{ chars = ($results | Measure-Object -Property Length -Sum).Sum } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true
        return $results
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'read' `
            -Arguments @{ row = $Row; col = $Col; length = $Length } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}

function Get-GsCursor {
    <#
    .SYNOPSIS
    Return the current cursor position.

    .PARAMETER Session
    The session handle returned by Connect-GsSession.

    .OUTPUTS
    pscustomobject with Row and Col (both 1-based).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Session
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $rc = $Session.Interop.GetCursor()
        $pos = [pscustomobject]@{ Row = [int]$rc[0]; Col = [int]$rc[1] }
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'cursor' `
            -Result @{ row = $pos.Row; col = $pos.Col } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true
        return $pos
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'cursor' `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}
