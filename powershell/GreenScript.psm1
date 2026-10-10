# GreenScript.psm1 - module entry point.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# Loads the C# interop shim once, then dot-sources each private file.
# Each private file defines one slice of the public API.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# BlueZone's host automation COM object (BZWhll.WhllObj) is a 32-bit in-process
# server. On 64-bit Windows the module must run under the 32-bit PowerShell
# host (C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe). The check
# below runs once at import. If the user wants to drive a non-COM backend
# (e.g. pure HLLAPI via ehlapi64.dll in a future release) this restriction
# will be scoped per-cmdlet rather than enforced at import.
if ([System.IntPtr]::Size -ne 4 -and -not $env:GREENSCRIPT_ALLOW_64BIT) {
    $msg = @(
        'GreenScript detected a 64-bit PowerShell host (pointer size {0}).'
        'The BZWhll.WhllObj COM server is 32-bit; Connect-GsSession will fail here.'
        'The popup cmdlets (Get-GsPopup / Read-GsPopup) work on either bitness.'
        'Re-run under C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe,'
        'or set $env:GREENSCRIPT_ALLOW_64BIT=1 to silence this warning.'
    ) -join ' '
    Write-Warning ($msg -f [System.IntPtr]::Size)
}

$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:PrivateDir = Join-Path $script:ModuleRoot 'private'

# Order matters: Interop defines types used by the rest; Audit is sourced
# before anything that writes audit records.
$loadOrder = @(
    'Interop.ps1',
    'Audit.ps1',
    'Session.ps1',
    'Screen.ps1',
    'Wait.ps1',
    'Keys.ps1',
    'Popup.ps1'
)

foreach ($file in $loadOrder) {
    $path = Join-Path $script:PrivateDir $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "GreenScript: expected private file not found: $path"
    }
    . $path
}

Export-ModuleMember -Function @(
    'Connect-GsSession',
    'Disconnect-GsSession',
    'Read-GsScreen',
    'Get-GsCursor',
    'Send-GsKeys',
    'Wait-GsText',
    'Get-GsPopup',
    'Read-GsPopup',
    'Write-GsAudit',
    'Get-GsAuditPath',
    'Set-GsAuditPath'
)
