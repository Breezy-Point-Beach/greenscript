# GreenScript.Tests.ps1 - Pester 5 suite.
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the MIT License
#
# These tests drive every cmdlet through a fake interop object, so they run
# on any Windows machine (and on CI) without BlueZone installed. The one thing
# they cannot prove is that the real BZWhll COM calls behave; that is verified
# by running examples/01-read-screen.ps1 against a live session.
#
# Run:  Invoke-Pester .\tests  (Pester 5+; Windows PowerShell 5.1 or pwsh)

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\powershell\GreenScript.psd1'

    # CI runners and most dev boxes are 64-bit; silence the import-time warning.
    $env:GREENSCRIPT_ALLOW_64BIT = '1'
    Import-Module $script:ModulePath -Force

    $script:TmpLog = Join-Path ([System.IO.Path]::GetTempPath()) ('greenscript-tests-{0}.jsonl' -f [guid]::NewGuid())
    Set-GsAuditPath -Path $script:TmpLog

    function script:New-FakeSession {
        param(
            [string[]] $Screen = @('ROW ONE', 'ROW TWO', 'ROW THREE'),
            [int] $WaitCode = 0
        )
        $interop = [pscustomobject]@{
            Sent     = New-Object System.Collections.ArrayList
            Screen   = $Screen
            WaitCode = $WaitCode
            Disposed = $false
        }
        $interop | Add-Member -MemberType ScriptMethod -Name ReadScreen -Value {
            param($length, $row, $col)
            $line = ''
            if ($row -ge 1 -and $row -le $this.Screen.Count) { $line = [string]$this.Screen[$row - 1] }
            $line.PadRight(600).Substring($col - 1, $length)
        }
        $interop | Add-Member -MemberType ScriptMethod -Name GetCursor -Value {
            , [int[]]@(3, 7)
        }
        $interop | Add-Member -MemberType ScriptMethod -Name SendKey -Value {
            param($keys)
            [void]$this.Sent.Add($keys)
        }
        $interop | Add-Member -MemberType ScriptMethod -Name WaitForText -Value {
            param($text, $row, $col, $seconds)
            $this.WaitCode
        }
        $interop | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
            $this.Disposed = $true
        }
        [pscustomobject]@{
            Tag       = '<fake>'
            Rows      = $Screen.Count
            Cols      = 80
            Interop   = $interop
            CreatedAt = Get-Date
        }
    }

    function script:Get-LastAudit {
        Get-Content -LiteralPath $script:TmpLog | Select-Object -Last 1 | ConvertFrom-Json
    }
}

AfterAll {
    Set-GsAuditPath -Path $null
    Remove-Item -LiteralPath $script:TmpLog -ErrorAction SilentlyContinue
    Remove-Module GreenScript -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest and exports' {
    It 'has a valid manifest' {
        Test-ModuleManifest -Path $script:ModulePath | Should -Not -BeNullOrEmpty
    }

    It 'exports exactly the documented cmdlets' {
        $expected = @(
            'Connect-GsSession', 'Disconnect-GsSession',
            'Read-GsScreen', 'Get-GsCursor',
            'Send-GsKeys', 'Wait-GsText',
            'Get-GsPopup', 'Read-GsPopup',
            'Write-GsAudit', 'Get-GsAuditPath', 'Set-GsAuditPath'
        )
        $actual = @((Get-Module GreenScript).ExportedFunctions.Keys | Sort-Object)
        $actual | Should -Be ($expected | Sort-Object)
    }
}

Describe 'Audit path' {
    It 'Get-GsAuditPath returns the override set in BeforeAll' {
        Get-GsAuditPath | Should -Be $script:TmpLog
    }

    It 'Set-GsAuditPath $null reverts to the per-user daily default' {
        Set-GsAuditPath -Path $null
        try {
            Get-GsAuditPath | Should -Match 'greenscript-\d{8}\.jsonl$'
        }
        finally {
            Set-GsAuditPath -Path $script:TmpLog
        }
    }
}

Describe 'Write-GsAudit' {
    It 'appends one JSON object per call with the expected fields' {
        Write-GsAudit -Session $null -Action 'event' -Arguments @{ a = 1 } -Result @{ b = 2 } `
            -DurationMs 5 -Ok $true -Cmd 'TestCmd'
        $rec = Get-LastAudit
        $rec.action   | Should -Be 'event'
        $rec.cmd      | Should -Be 'TestCmd'
        $rec.args.a   | Should -Be 1
        $rec.result.b | Should -Be 2
        $rec.ms       | Should -Be 5
        $rec.ok       | Should -BeTrue
        $rec.seq      | Should -BeGreaterThan 0
        $rec.ts       | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'
    }

    It 'includes err when Ok is false' {
        Write-GsAudit -Session $null -Action 'event' -Ok $false -ErrorMessage 'boom' -Cmd 'TestCmd'
        $rec = Get-LastAudit
        $rec.ok  | Should -BeFalse
        $rec.err | Should -Be 'boom'
    }

    It 'records the session tag when a session is given' {
        $s = New-FakeSession
        Write-GsAudit -Session $s -Action 'event' -Cmd 'TestCmd'
        (Get-LastAudit).session | Should -Be '<fake>'
    }
}

Describe 'Read-GsScreen' {
    BeforeEach { $script:s = New-FakeSession -Screen @('ALPHA LINE', 'BRAVO LINE', 'CHARLIE LINE') }

    It 'reads every row by default, full width' {
        $rows = @(Read-GsScreen -Session $script:s)
        $rows.Count | Should -Be 3
        $rows[1].Row | Should -Be 2
        $rows[1].Length | Should -Be 80
        $rows[1].Text.TrimEnd() | Should -Be 'BRAVO LINE'
    }

    It 'reads a single row slice with -Row/-Col/-Length' {
        $r = Read-GsScreen -Session $script:s -Row 3 -Col 9 -Length 4
        $r.Text | Should -Be 'LINE'
        $r.Row | Should -Be 3
        $r.Col | Should -Be 9
    }

    It 'writes a read audit record' {
        $null = Read-GsScreen -Session $script:s -Row 1
        (Get-LastAudit).action | Should -Be 'read'
    }
}

Describe 'Get-GsCursor' {
    It 'returns Row and Col from the interop' {
        $pos = Get-GsCursor -Session (New-FakeSession)
        $pos.Row | Should -Be 3
        $pos.Col | Should -Be 7
    }
}

Describe 'Wait-GsText' {
    It 'reports Found when the host returns 0' {
        $r = Wait-GsText -Session (New-FakeSession -WaitCode 0) -Text 'X' -Row 1 -Col 1 -TimeoutSeconds 1
        $r.Found | Should -BeTrue
        $r.StatusCode | Should -Be 0
    }

    It 'reports not Found on timeout code 4 without throwing' {
        $r = Wait-GsText -Session (New-FakeSession -WaitCode 4) -Text 'X' -Row 1 -Col 1 -TimeoutSeconds 1
        $r.Found | Should -BeFalse
        $r.StatusCode | Should -Be 4
    }
}

Describe 'Send-GsKeys' {
    BeforeEach { $script:s = New-FakeSession }

    It 'sends when confirmation is suppressed' {
        Send-GsKeys -Session $script:s -Keys 'WAQ<Enter>' -Confirm:$false
        $script:s.Interop.Sent.Count | Should -Be 1
        $script:s.Interop.Sent[0] | Should -Be 'WAQ<Enter>'
        $rec = Get-LastAudit
        $rec.action | Should -Be 'send'
        $rec.result.sent | Should -BeTrue
    }

    It 'does not send under -WhatIf' {
        Send-GsKeys -Session $script:s -Keys 'WAQ<Enter>' -WhatIf
        $script:s.Interop.Sent.Count | Should -Be 0
    }

    It 'detects forbidden keys case-insensitively and sends with -Force' {
        Send-GsKeys -Session $script:s -Keys 'abc<f3>' -Force -Confirm:$false
        $script:s.Interop.Sent[0] | Should -Be 'abc<f3>'
        $rec = Get-LastAudit
        @($rec.args.forbidden) | Should -Contain '<F3>'
    }

    It 'an empty forbidden list disables the extra prompt' {
        Send-GsKeys -Session $script:s -Keys '<F3>' -ForbiddenKeys @() -Confirm:$false
        $script:s.Interop.Sent.Count | Should -Be 1
    }

    It 'honours a custom forbidden list' {
        Send-GsKeys -Session $script:s -Keys '<PF12>' -ForbiddenKeys @('<PF12>') -Force -Confirm:$false
        @((Get-LastAudit).args.forbidden) | Should -Contain '<PF12>'
    }
}

Describe 'Disconnect-GsSession' {
    It 'disposes the interop and is idempotent' {
        $s = New-FakeSession
        Disconnect-GsSession -Session $s
        $s.Interop.Disposed | Should -BeTrue
        { Disconnect-GsSession -Session $s } | Should -Not -Throw
        (Get-LastAudit).action | Should -Be 'disconnect'
    }

    It 'accepts the session from the pipeline' {
        $s = New-FakeSession
        $s | Disconnect-GsSession
        $s.Interop.Disposed | Should -BeTrue
    }
}

Describe 'Source hygiene' {
    BeforeAll {
        $script:PrivateDir = Join-Path $PSScriptRoot '..\powershell\private'
        $script:Psm1 = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..\powershell\GreenScript.psm1')
    }

    It 'no source file declares a parameter named $Args (shadows the automatic variable)' {
        $hits = Get-ChildItem -LiteralPath $script:PrivateDir -Filter *.ps1 |
            Select-String -Pattern '\$Args\b' -CaseSensitive
        @($hits).Count | Should -Be 0
    }

    It 'every private file is listed in the module load order' {
        Get-ChildItem -LiteralPath $script:PrivateDir -Filter *.ps1 | ForEach-Object {
            $script:Psm1 | Should -Match ([regex]::Escape($_.Name))
        }
    }

    It 'no source file references a non-MIT license' {
        $root = Join-Path $PSScriptRoot '..'
        # Exclude .git and this tests folder (this file names the pattern itself).
        $hits = Get-ChildItem -LiteralPath $root -Recurse -Include *.ps1, *.psm1, *.psd1, *.bas, *.md |
            Where-Object { $_.FullName -notmatch '[\\/](\.git|tests)[\\/]' } |
            Select-String -Pattern 'Apache' -SimpleMatch
        @($hits).Count | Should -Be 0
    }
}
