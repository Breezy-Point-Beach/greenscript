# Security model — greenscript v0.1

## What it is

`greenscript` runs locally, under the credentials of whoever is signed into
the Windows session. It drives a terminal emulator the operator is already
running. It does not open network sockets, make outbound HTTP calls, or
exchange data with any remote service. The only persistent artifact it writes
is the JSONL audit log.

## Trust boundaries

| Boundary                | Whose trust                                  |
|-------------------------|----------------------------------------------|
| Windows user account    | Operator's own                               |
| BlueZone session        | Operator's existing session                  |
| COM / MSHTML            | Operating-system interfaces                  |
| Audit log               | File on the operator's local disk            |
| Network                 | None — no sockets opened                     |

`greenscript` does not request, store, or transmit credentials. If a terminal
session requires a logon, the operator performs that logon in BlueZone as they
always have; `greenscript` attaches to the already-open session.

## Approval model

The `Send-GsKeys` cmdlet is the only one that can change state on the host.
It uses PowerShell's standard `SupportsShouldProcess` machinery with
`ConfirmImpact = 'High'`:

- Interactive sessions prompt before every send.
- `-Confirm:$false` suppresses the prompt (use only after reviewing what will
  be sent).
- `-WhatIf` prints the proposed send and does not call the host.

On top of `ShouldProcess`, a **forbidden-key list** fires a second, mandatory
prompt whenever the key sequence contains any of the configured tokens. The
default list is:

| Token    | Typical meaning on dealer-DMS hosts (e.g. CDK Drive)        |
|----------|-------------------------------------------------------------|
| `<F3>`   | Exit / Save (depending on screen) — potentially destructive |
| `<F5>`   | New — may clear or create a record                          |
| `<SF6>`  | Update — writes to the DMS                                  |

Tokens are matched case-insensitively. Pass `-ForbiddenKeys @()` to disable the
second prompt for a specific call, or `-Force` to bypass it; pass your own list
to match the host you drive, since F-key meanings differ between screens even
on one system. The ShouldProcess prompt remains active unless `-Confirm:$false`
is passed as well.

The VBA module (`vba\GreenScript.bas`) implements the same forbidden-key
pattern with a `MsgBox` approval prompt. The default forbidden tokens are
identical.

## Audit log

Every cmdlet that reads from or writes to the terminal appends a JSONL record
to the audit log. Records include timestamp, cmdlet name, action, parameters,
result, duration, success flag, and (on failure) the error message. The log
is append-only; no cmdlet rewrites or deletes records.

Location: `%LOCALAPPDATA%\GreenScript\logs\greenscript-YYYYMMDD.jsonl` unless
overridden with `Set-GsAuditPath`.

Rotation: by filename, daily.

Retention: the module does not delete old logs. Operators or administrators
should set up filesystem-level retention appropriate to their policy.

Content sensitivity: the audit log records **the keys sent** and **the
parameters passed to cmdlets**. If a workflow types sensitive data into the
terminal (passwords, SSNs, dealer customer data), that content appears in
the audit log. Treat the log as sensitive and protect it accordingly. There
is no built-in masking in v0.1; this will be added before 1.0.

## Threats and mitigations

| Threat                                                         | Mitigation                                                                                                 |
|----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| Script sends unintended destructive keys                       | ShouldProcess prompt + forbidden-key prompt. Both must be explicitly suppressed to run unattended.          |
| Script attaches to the wrong session                           | `Connect-GsSession` with no `-SessionName` is the active session; be explicit when scripting unattended.    |
| Session is left connected after error                          | All examples use `try/finally` to call `Disconnect-GsSession`. Mirror this pattern in your own scripts.     |
| Audit log leaks sensitive content                              | File ACLs on the audit directory. Future: masking policies. For now, treat the log as sensitive.            |
| COM object is replaced by a malicious installer                | Standard Windows COM registration hygiene. Verify BlueZone installation integrity.                          |
| Unintended BZWhll calls through the exposed `Interop` property | `Interop` is on the session handle for advanced use. Documented as advanced-only; do not rely on it in production. |

## What `greenscript` deliberately does NOT do

- Does not connect to any remote service, including on behalf of plugins.
- Does not auto-update, phone home, or submit telemetry.
- Does not elevate privileges. If a script needs admin, launch it from an
  admin PowerShell.
- Does not interact with any AI model, local or hosted.
- Does not sign, encrypt, or redact the audit log on its own.

## Reporting a vulnerability

See [CONTRIBUTING.md](../CONTRIBUTING.md#security).
