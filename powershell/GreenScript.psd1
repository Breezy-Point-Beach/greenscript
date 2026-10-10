#
# Module manifest for GreenScript
#
# Copyright 2026 Breezy Point Beach, LLC
# Licensed under the Apache License, Version 2.0
#

@{
    RootModule        = 'GreenScript.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '7f8c5e1a-9b23-4d6a-8e5f-2a1b4c7d8e90'
    Author            = 'Breezy Point Beach, LLC'
    CompanyName       = 'Breezy Point Beach, LLC'
    Copyright         = 'Copyright (c) 2026 Breezy Point Beach, LLC. Licensed under Apache 2.0.'
    Description       = 'Green-screen automation framework for Windows. Drives terminal emulators (BlueZone and compatible) and their GUI faceplates (LegaSuite popups via MSHTML) from PowerShell, with approval gates and JSONL audit logging. Uses only runtimes shipped with Windows.'

    PowerShellVersion = '5.1'

    # No external module dependencies. Everything used is in-box.
    RequiredModules   = @()
    RequiredAssemblies = @()

    FunctionsToExport = @(
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

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('BlueZone', 'Terminal', 'Emulator', '3270', '5250', 'Automation', 'HLLAPI', 'LegaSuite', 'Mainframe')
            LicenseUri   = 'https://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/Breezy-Point-Beach/greenscript'
            ReleaseNotes = 'v0.1.0 — initial scaffold. BZWhll COM driver, LegaSuite popup reader via IHTMLDocument2, JSONL audit log, approval gate on key sends. API will change before 1.0.'
        }
    }
}
