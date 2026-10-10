# Audit.ps1 - JSONL audit logger.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# Every cmdlet that reads from or writes to the terminal appends one JSONL
# record to the audit log. The log lives at a per-user default under
# %LOCALAPPDATA%\GreenScript\logs\greenscript-YYYYMMDD.jsonl, rotated daily.
# A caller can override with Set-GsAuditPath or by passing -AuditPath to any
# cmdlet that accepts it.
#
# JSONL schema (fields may be absent when not applicable):
#   ts      ISO-8601 UTC timestamp (ms precision)
#   seq     monotonic integer, module-wide, resets on module import
#   session session tag (e.g. "<active>", "A", "B")
#   cmd     cmdlet name (e.g. "Send-GsKeys")
#   action  short verb (e.g. "read", "send", "wait", "cursor", "popup", "connect")
#   args    parameters relevant to the action (hashtable serialised as JSON)
#   result  cmdlet result summary (hashtable)
#   ms      duration in milliseconds
#   ok      $true on success, $false when an error terminated the call
#   err     error message when ok=$false
#   user    USERNAME environment variable
#   host    COMPUTERNAME environment variable
#   pid     the Windows process id

$script:AuditSeq = 0
$script:AuditPath = $null

function Get-GsAuditPath {
    <#
    .SYNOPSIS
    Return the current audit log file path.

    .DESCRIPTION
    Resolves to the explicit path set by Set-GsAuditPath, or to the per-user
    default under %LOCALAPPDATA%\GreenScript\logs\. The default rotates daily
    by filename.
    #>
    [CmdletBinding()]
    param()

    if ($script:AuditPath) { return $script:AuditPath }

    $base = Join-Path $env:LOCALAPPDATA 'GreenScript\logs'
    if (-not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }
    $day = (Get-Date).ToString('yyyyMMdd')
    return Join-Path $base "greenscript-$day.jsonl"
}

function Set-GsAuditPath {
    <#
    .SYNOPSIS
    Override the audit log file path for this PowerShell session.

    .PARAMETER Path
    An absolute or relative path to a .jsonl file. The parent directory is
    created if missing. Pass $null to revert to the per-user default.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $script:AuditPath = $null
        return
    }
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $dir = Split-Path -Parent $resolved
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $script:AuditPath = $resolved
}

function Write-GsAudit {
    <#
    .SYNOPSIS
    Append a single JSONL record to the audit log.

    .DESCRIPTION
    This cmdlet is called internally by every other GreenScript cmdlet to
    record what happened. Callers can also invoke it directly to log
    workflow-level events alongside the keystroke-level ones.

    .PARAMETER Session
    The session handle returned by Connect-GsSession, or $null.

    .PARAMETER Action
    A short verb (connect, disconnect, read, cursor, send, wait, popup, event).

    .PARAMETER Arguments
    Hashtable of arguments relevant to the action.

    .PARAMETER Result
    Hashtable summarising the action's result.

    .PARAMETER DurationMs
    Elapsed time in milliseconds.

    .PARAMETER Ok
    $true when the operation succeeded.

    .PARAMETER ErrorMessage
    Error message string when Ok is $false.

    .PARAMETER Cmd
    Cmdlet name that produced this record. Defaults to the caller's.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Session,
        [Parameter(Mandatory)] [string] $Action,
        [hashtable] $Arguments = @{},
        [hashtable] $Result = @{},
        [int] $DurationMs = 0,
        [bool] $Ok = $true,
        [string] $ErrorMessage,
        [string] $Cmd
    )

    if (-not $Cmd) {
        $Cmd = (Get-PSCallStack)[1].Command
    }

    $script:AuditSeq++
    $record = [ordered]@{
        ts      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        seq     = $script:AuditSeq
        session = if ($Session) { [string]$Session.Tag } else { $null }
        cmd     = $Cmd
        action  = $Action
        args    = $Arguments
        result  = $Result
        ms      = $DurationMs
        ok      = $Ok
        user    = $env:USERNAME
        host    = $env:COMPUTERNAME
        pid     = $PID
    }
    if (-not $Ok -and $ErrorMessage) { $record.err = $ErrorMessage }

    $json = $record | ConvertTo-Json -Compress -Depth 6
    $path = Get-GsAuditPath
    # Append atomically; UTF8 without BOM to keep JSONL clean.
    [System.IO.File]::AppendAllText(
        $path,
        $json + [System.Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding $false))
}
