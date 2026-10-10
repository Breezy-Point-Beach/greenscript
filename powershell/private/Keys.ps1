# Keys.ps1 - Send-GsKeys with approval gate and forbidden-key policy.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# Send-GsKeys uses PowerShell's standard SupportsShouldProcess machinery, so
# -WhatIf shows what would be sent and -Confirm prompts before sending. The
# default ConfirmImpact is High, so interactive sessions always prompt unless
# the caller explicitly passes -Confirm:$false.
#
# On top of ShouldProcess, there is a per-session "forbidden keys" list that
# ALWAYS prompts even when -Confirm:$false is in effect. The default list
# contains the destructive F-keys on common CDK Drive screens (F3=Exit/Save,
# F5=New, SF6=Update). Callers can override with -ForbiddenKeys or disable
# the extra prompt with -Force.
#
# Keys are expressed in BlueZone's native notation:
#   plain text: "WAQ"
#   special:    "<Enter>" "<Tab>" "<F3>" "<SF6>" "<Clear>"
# See the Rocket BlueZone SendKey reference for the full list.

$script:DefaultForbiddenKeys = @('<F3>', '<F5>', '<SF6>')

function Send-GsKeys {
    <#
    .SYNOPSIS
    Send keystrokes to the terminal, with an approval gate.

    .DESCRIPTION
    Sends a key sequence through BZWhll.SendKey. Honors PowerShell's -WhatIf
    and -Confirm. In addition, any key sequence containing one of the
    ForbiddenKeys always prompts, even when -Confirm:$false is passed. Use
    -Force to bypass the forbidden-key prompt (-Confirm still applies unless
    separately disabled).

    .PARAMETER Session
    The session handle returned by Connect-GsSession.

    .PARAMETER Keys
    The key sequence to send, in BlueZone notation.

    .PARAMETER ForbiddenKeys
    Keys that always prompt. Default: '<F3>', '<F5>', '<SF6>'. Pass @() to
    disable the extra prompt for this call.

    .PARAMETER Force
    Bypass the forbidden-key prompt. ShouldProcess (-Confirm / -WhatIf) still
    applies unless explicitly suppressed.

    .EXAMPLE
    Send-GsKeys -Session $s -Keys 'WAQ<Enter>'

    .EXAMPLE
    Send-GsKeys -Session $s -Keys '<F3>' -Force -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Session,
        [Parameter(Mandatory)] [string] $Keys,
        [string[]] $ForbiddenKeys = $script:DefaultForbiddenKeys,
        [switch] $Force
    )

    $hit = @()
    if ($ForbiddenKeys -and $ForbiddenKeys.Count -gt 0) {
        foreach ($f in $ForbiddenKeys) {
            if ($Keys -like "*${f}*") { $hit += $f }
        }
    }

    if ($hit.Count -gt 0 -and -not $Force) {
        $answer = $Host.UI.PromptForChoice(
            'Forbidden key sequence',
            "The key sequence '$Keys' contains $($hit -join ', ') which may be destructive on this screen. Proceed?",
            @(
                (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Send the keys'),
                (New-Object System.Management.Automation.Host.ChoiceDescription '&No',  'Cancel')
            ),
            1)
        if ($answer -ne 0) {
            Write-GsAudit -Session $Session -Action 'send' `
                -Args @{ keys = $Keys; forbidden = $hit } `
                -Result @{ canceled = $true; reason = 'forbidden-key denied' } `
                -DurationMs 0 -Ok $true
            Write-Verbose "Send-GsKeys canceled by operator (forbidden key)."
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess("session=$($Session.Tag) keys='$Keys'", 'Send-GsKeys')) {
        Write-GsAudit -Session $Session -Action 'send' `
            -Args @{ keys = $Keys } `
            -Result @{ canceled = $true; reason = 'ShouldProcess denied' } `
            -DurationMs 0 -Ok $true
        return
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $Session.Interop.SendKey($Keys)
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'send' `
            -Args @{ keys = $Keys; forbidden = $hit } `
            -Result @{ sent = $true } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $true
    }
    catch {
        $sw.Stop()
        Write-GsAudit -Session $Session -Action 'send' `
            -Args @{ keys = $Keys; forbidden = $hit } `
            -DurationMs $sw.ElapsedMilliseconds -Ok $false `
            -ErrorMessage $_.Exception.Message
        throw
    }
}
