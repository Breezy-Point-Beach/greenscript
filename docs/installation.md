# Installation

`greenscript` has no third-party runtime dependencies. Everything it uses
ships with Windows or with your BlueZone bundle. There is nothing to compile,
nothing to download beyond this repository.

## Requirements

| Component                        | Where it comes from                       |
|----------------------------------|-------------------------------------------|
| Windows 10 or 11                 | Operating system                          |
| PowerShell 5.1                   | Shipped with Windows                      |
| .NET Framework 4.7.2 or newer    | Shipped with Windows                      |
| Rocket BlueZone (any current)    | Your BlueZone / CDK Drive installation    |
| MSHTML (`IHTMLDocument2`)        | Shipped with Windows                      |

For the VBA module you additionally need either BlueZone VBA (installable
Rocket add-on, often bundled with Drive) or Office with VBA enabled.

## Important: 32-bit PowerShell

The BZWhll host automation COM object is **32-bit**. A 64-bit PowerShell host
cannot `CreateObject` it; you will get:

> *ActiveX component can't create object: 'BZWhll.WhllObj'*

On 64-bit Windows, run PowerShell from:

```
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe
```

A shortcut on the desktop is the simplest workflow. The module warns at
import if it detects a 64-bit host.

## Install options

### Option A — Run from the repository (recommended for v0.1)

```powershell
# From the 32-bit PowerShell:
cd C:\path\to\greenscript
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module .\powershell\GreenScript.psd1 -Force
```

### Option B — Install into the user module path

```powershell
$dest = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules\GreenScript'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Recurse -Force -Path .\powershell\* -Destination $dest
Import-Module GreenScript
```

After that, every new PowerShell session can `Import-Module GreenScript`
without a path.

### Option C — VBA module

**Inside BlueZone VBA:**
1. Open the BlueZone session you want to automate.
2. Macros → Visual Basic Editor.
3. File → Import File… → select `vba\GreenScript.bas`.

**Inside Excel VBA:**
1. Open Excel.
2. Alt+F11 to open the VBA editor.
3. File → Import File… → select `vba\GreenScript.bas`.

Keep a copy of your `.bvp` file; a CDK Drive upgrade may replace the shipped
project.

## Verify

```powershell
Import-Module .\powershell\GreenScript.psd1 -Force

# Attach to the active BlueZone session (open one first).
$s = Connect-GsSession

# Read-only check.
Read-GsScreen -Session $s | Format-Table Row, Text

# Release.
Disconnect-GsSession $s
```

If `Connect-GsSession` returns a session handle and `Read-GsScreen` returns 24
rows, you are done.

## Troubleshooting

**`CreateObject` fails with "ActiveX component can't create object"**
You are in a 64-bit PowerShell. Switch to `C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`.

**`BZWhll.WhllObj is not registered`**
BlueZone is not installed, or its COM registration got clobbered. Re-run the
BlueZone installer. On CDK Drive installs the registration is handled by the
Drive installer; a Drive repair usually fixes it.

**Audit log is in an unexpected location**
By default it is `%LOCALAPPDATA%\GreenScript\logs\greenscript-YYYYMMDD.jsonl`.
Override with `Set-GsAuditPath -Path 'D:\logs\myrun.jsonl'`.

**Keystrokes do not land in the session I expected**
`Connect-GsSession` with no `-SessionName` attaches to the *active* session —
the one in front of the user. Pass `-SessionName A` (or whichever presentation
space you want) to be explicit.
