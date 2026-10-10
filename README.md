# greenscript

A green-screen automation framework for Windows. Drive terminal emulators and
their GUI faceplates from PowerShell and VBA, with approval gates and audit
logging built in, using only the runtimes shipped with Windows.

**Status:** v0.1 — early. API will change.
**License:** [MIT](LICENSE)

## What it is

Terminal emulators like Rocket BlueZone, IBM Personal Communications, and Micro
Focus Reflection expose automation surfaces that have been used for decades to
script against the mainframe, midrange, and legacy applications behind them.
`greenscript` wraps those surfaces in a small, intentional PowerShell module and
VBA module, adds an approval model and a JSONL audit log, and ships recipe
scripts for the patterns people actually need.

The library is dealer-, vendor-, and vertical-agnostic. If you have a
BlueZone-driven line-of-business system, `greenscript` gives you a cleaner API
than raw COM calls and a safer execution model than hand-rolled macros.

## What it is not

- Not an RPA platform. There is no visual designer, no cloud orchestrator, no
  licensed runtime.
- Not an AI product. The connector has zero dependency on any LLM, local or
  hosted.
- Not an integration product. It drives the terminal emulator the operator is
  already running, under the operator's own credentials, from their own
  workstation.

## Why "native Windows"

Every runtime `greenscript` uses already ships on a modern Windows machine:

- **PowerShell 5.1** — baked into Windows 10 and 11.
- **BlueZone VBA** — Rocket Software's add-on, included with most BlueZone
  deployments.
- **.NET Framework 4.x** — present on every supported Windows release.
- **MSHTML (`IHTMLDocument2`)** — the Windows HTML document interface used to
  read GUI popups rendered as embedded browser controls.

No npm, no pip, no runtime installer. The connector is scripts and VBA that run
on tools the workstation already has.

## Install

```powershell
# From a cloned checkout:
Import-Module .\powershell\GreenScript.psd1

# Or copy the module into the user module path:
Copy-Item -Recurse .\powershell $env:USERPROFILE\Documents\WindowsPowerShell\Modules\GreenScript
Import-Module GreenScript
```

BlueZone's COM object is 32-bit. On 64-bit Windows, run PowerShell from
`C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`. The module will
warn and exit if invoked under a 64-bit host.

See [docs/installation.md](docs/installation.md) for details and troubleshooting.

## Quick example

```powershell
Import-Module GreenScript

$session = Connect-GsSession   # attaches to the active BlueZone session

Read-GsScreen -Session $session | Format-Table Row, Text

Send-GsKeys   -Session $session -Keys "WAQ<Enter>" -Confirm
Wait-GsText   -Session $session -Text "Work a Quote" -Row 1 -TimeoutSeconds 10

Disconnect-GsSession $session
```

Every keystroke-sending call runs through `[CmdletBinding(SupportsShouldProcess)]`
and prompts for confirmation by default. `-Confirm:$false` disables the prompt
for scripted scenarios; `-WhatIf` previews without sending.

## Public API

| Cmdlet                 | Purpose                                                 |
|------------------------|---------------------------------------------------------|
| `Connect-GsSession`    | Attach to a BlueZone session; returns a session handle. |
| `Disconnect-GsSession` | Release the session.                                    |
| `Read-GsScreen`        | Read the full terminal screen (default 24×80).          |
| `Get-GsCursor`         | Return current cursor row/column.                       |
| `Send-GsKeys`          | Send keys to the host, with approval gate.              |
| `Wait-GsText`          | Wait for text to appear at a specific row/column.       |
| `Get-GsPopup`          | Enumerate open LegaSuite / embedded-browser popups.     |
| `Read-GsPopup`         | Parse a popup's fields, buttons, and visible text.      |
| `Write-GsAudit`        | Append a JSONL audit entry (keyed by session).          |

See [docs/api.md](docs/api.md) for parameter detail and examples.

## Examples

Three self-contained scripts in [`examples/`](examples/) demonstrate the
module without any AI involvement:

- [`01-read-screen.ps1`](examples/01-read-screen.ps1) — connect, read, print.
- [`02-recall-quote.ps1`](examples/02-recall-quote.ps1) — navigate to a workflow
  by quote number, read the resulting worksheet.
- [`03-sales-tax-upload.ps1`](examples/03-sales-tax-upload.ps1) — pattern for
  bulk data entry into a form, with per-row approval option.

Run with `powershell -NoProfile -ExecutionPolicy Bypass -File examples\01-read-screen.ps1`.

## Security model

`greenscript` operates under the credentials of whoever is signed into the
Windows session. It does not store, transmit, or request credentials. It does
not open network sockets, make outbound HTTP calls, or write to any file
outside the audit log directory the user configures.

The approval gate on `Send-GsKeys` is enforced through PowerShell's standard
`SupportsShouldProcess` mechanism. You get the usual `-WhatIf` / `-Confirm`
semantics, plus a configurable deny-list of key sequences that always prompt
regardless of `-Confirm:$false` (default list: `<F3>`, `<F5>`, `<SF6>` — the
Save, New, and Update keys on common CDK Drive screens).

See [docs/security.md](docs/security.md) for the full model.

## Prior art

- Rocket BlueZone Advanced Automation Developer Guide
- Microsoft Power Automate Desktop's terminal emulation actions (same
  `ehlapi64.dll` HLLAPI surface)
- IBM EHLLAPI specification
- The 2014-era [hllapi-node](https://github.com/Chris-Cullins/hllapi-node)
  project (CoffeeScript, abandoned)

`greenscript` is not a fork of any of these. It is a modern PowerShell/VBA
interpretation of the same automation patterns.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Project

Published by **Breezy Point Beach, LLC**.

Repository: `https://github.com/Breezy-Point-Beach/greenscript`
