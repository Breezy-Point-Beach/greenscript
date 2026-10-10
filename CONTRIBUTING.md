# Contributing to greenscript

Thanks for considering a contribution. This project is deliberately small; the
bar for additions is "does it help someone drive a green-screen application
from a Windows workstation without installing a third-party runtime?"

## What belongs here

- Native-Windows automation primitives for terminal emulators and their GUI
  faceplates: BZWhll (COM), HLLAPI (EHLLAPI DLL via P/Invoke), MSHTML popup
  reading, print-queue capture, SFTP session automation.
- Safety primitives: approval gates, dry-run modes, auditable JSONL logging.
- Session helpers: templates, keyboard mapping, screen-diff utilities.
- Recipe examples that exercise the primitives against common workflows.
- Tests that mock the COM/DLL surface so they can run in CI without a real
  emulator.

## What does not belong here

- Anything AI, LLM, or model-related. The connector is deliberately not
  AI-aware. Those pieces belong in a separate project that uses `greenscript`
  as an input adapter.
- Vendor- or vertical-specific business logic (DMS accounting rules,
  dealership workflow packs, healthcare reconciliation logic). Those belong in
  product repositories that consume `greenscript`.
- Runtime dependencies that are not shipped with Windows. No npm packages, no
  pip modules, no Node/Python/Ruby/Java requirements. .NET Framework 4.x and
  PowerShell 5.1 are the floor; anything beyond that needs discussion first.

## Development setup

1. Clone the repo on a Windows machine with a BlueZone session you can safely
   attach to (a test session, not production).
2. From a 32-bit PowerShell (`C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`; no elevation needed):

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   Import-Module .\powershell\GreenScript.psd1 -Force
   ```

3. Install Pester 5+ and PSScriptAnalyzer:

   ```powershell
   Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force
   Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
   ```

4. Run the test suite:

   ```powershell
   Invoke-Pester .\tests\
   Invoke-ScriptAnalyzer -Path .\powershell\ -Recurse
   ```

## Pull requests

- One topic per PR. A new cmdlet, a bug fix, a doc improvement — not all three.
- Include a Pester test for every behavioral change.
- `PSScriptAnalyzer` must pass with no warnings. Suppressions are allowed with
  a short comment explaining why.
- Public API changes need a brief rationale in the PR description and a
  corresponding `docs/api.md` update.

## Reporting issues

Please include:

- Your Windows version (`[System.Environment]::OSVersion.VersionString`).
- Your PowerShell host and version (`$Host.Name`, `$PSVersionTable.PSVersion`,
  and `[System.IntPtr]::Size` — 4 means 32-bit, 8 means 64-bit).
- Your BlueZone version (Help → About in BlueZone).
- A minimal `.ps1` that reproduces the problem.
- The relevant stretch of the JSONL audit log, with any sensitive values redacted.

## Security

If you believe you have found a security issue, please do not file a public
issue. Use GitHub's private vulnerability reporting instead: open the
repository's **Security** tab and choose **Report a vulnerability**. Reports
go only to the maintainers.

## License

By submitting a contribution you agree it is licensed under the project's
MIT license.
