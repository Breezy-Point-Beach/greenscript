# Session.ps1 - Connect / Disconnect / session handle shape.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# A GreenScript session handle is a plain [pscustomobject] with:
#   Tag       - string, cosmetic identifier used in audit records
#   Rows      - int, terminal row count (default 24)
#   Cols      - int, terminal column count (default 80; set to 132 if the
#               session is in 132-column mode)
#   Interop   - [GreenScript.BlueZoneInterop] instance (the actual COM wrapper)
#   CreatedAt - DateTime when Connect-GsSession returned
#
# Callers should treat the handle as opaque and pass it to the other cmdlets.
# Interop is exposed only so advanced users can call methods we have not
# wrapped yet; relying on it is at your own risk and may break between
# versions.

function Connect-GsSession {
    <#
    .SYNOPSIS
    Attach to a BlueZone session and return a session handle.

    .DESCRIPTION
    Creates a BZWhll.WhllObj COM instance and calls Connect. The default
    attaches to the currently active session (the one in front of the user).
    Pass -SessionName with a letter ("A", "B", ...) to attach to a specific
    presentation space.

    .PARAMETER SessionName
    BlueZone session name. Default "" (active session).

    .PARAMETER Rows
    Terminal row count. Default 24.

    .PARAMETER Cols
    Terminal column count. Default 80. Set to 132 for 132-column screens.

    .EXAMPLE
    $s = Connect-GsSession
    Read-GsScreen -Session $s | Format-Table Row, Text

    .OUTPUTS
    pscustomobject with properties Tag, Rows, Cols, Interop, CreatedAt.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string] $SessionName = '',
        [ValidateRange(1, 100)] [int] $Rows = 24,
        [ValidateRange(1, 500)] [int] $Cols = 80
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $interop = New-Object GreenScript.BlueZoneInterop
        $interop.Connect($SessionName)
        $sw.Stop()

        $session = [pscustomobject]@{
            Tag       = $interop.SessionTag
            Rows      = $Rows
            Cols      = $Cols
            Interop   = $interop
            CreatedAt = Get-Date
        }

        Write-GsAudit -Session $session -Action 'connect' `
            -Args @{ sessionName = $SessionName; rows = $Rows; cols = $Cols } `
            -Result @{ tag = $session.Tag } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true

        return $session
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $null -Action 'connect' `
            -Args @{ sessionName = $SessionName } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}

function Disconnect-GsSession {
    <#
    .SYNOPSIS
    Release a BlueZone session handle.

    .DESCRIPTION
    Calls Disconnect on the underlying COM object and releases the COM
    reference. Safe to call more than once; subsequent calls are no-ops.

    .PARAMETER Session
    The session handle returned by Connect-GsSession.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject] $Session
    )

    process {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            if ($Session.Interop) {
                $Session.Interop.Dispose()
            }
            $sw.Stop()
            Write-GsAudit -Session $Session -Action 'disconnect' `
                -DurationMs $sw.ElapsedMilliseconds -Ok $true
        }
        catch {
            $sw.Stop()
            Write-GsAudit -Session $Session -Action 'disconnect' `
                -DurationMs $sw.ElapsedMilliseconds -Ok $false `
                -ErrorMessage $_.Exception.Message
            throw
        }
    }
}
