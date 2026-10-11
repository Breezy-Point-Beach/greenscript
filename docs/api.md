# API reference — greenscript v0.1

All cmdlets are exported from the `GreenScript` PowerShell module. Verb-noun
pairs follow PowerShell conventions; the noun prefix is `Gs`.

Session handles returned by `Connect-GsSession` are `pscustomobject` with
`Tag`, `Rows`, `Cols`, `Interop`, `CreatedAt`. Treat them as opaque; `Interop`
is exposed only for advanced BZWhll calls the module has not yet wrapped.

---

## `Connect-GsSession`

Attach to a BlueZone session.

```powershell
Connect-GsSession [-SessionName <string>] [-Rows <int>] [-Cols <int>]
```

| Parameter    | Default        | Notes                                                 |
|--------------|----------------|-------------------------------------------------------|
| SessionName  | `""`           | `""` means the active session. Use `A`, `B`, etc. for a specific presentation space. |
| Rows         | 24             | Session row count.                                    |
| Cols         | 80             | Session column count. Set to 132 for 132-column mode. |

Returns a session handle.

---

## `Disconnect-GsSession`

Release a session handle. Safe to call more than once.

```powershell
Disconnect-GsSession -Session <pscustomobject>
# or by pipeline
$session | Disconnect-GsSession
```

---

## `Read-GsScreen`

Read the terminal buffer and return rows.

```powershell
Read-GsScreen -Session <handle> [-Row <int>] [-Col <int>] [-Length <int>]
```

`-Row 0` (the default) returns every row up to `Session.Rows`; any other value
returns that single row. `-Col` sets the start column. `-Length 0` (the
default) reads to the end of the row; any other value reads that many
characters.

Each row is `pscustomobject` with `Row`, `Col`, `Length`, `Text`.

Example:
```powershell
Read-GsScreen -Session $s | Format-Table Row, Text
Read-GsScreen -Session $s -Row 1 -Col 20 -Length 40
```

---

## `Get-GsCursor`

Return the current cursor position as `pscustomobject` with `Row`, `Col`.

```powershell
$pos = Get-GsCursor -Session $s
"cursor is at row $($pos.Row), col $($pos.Col)"
```

Verified live against CDK Drive in October 2026: with the cursor in the
`Account:` input of the User Security Menu it returned row 4, col 19 — exactly
where the field sits on screen.

---

## `Send-GsKeys`

Send keys to the terminal, with an approval gate.

```powershell
Send-GsKeys -Session <handle> -Keys <string>
            [-ForbiddenKeys <string[]>] [-Force]
            [-WhatIf] [-Confirm]
```

Key sequences use BlueZone's native notation:
- Plain text: `WAQ`
- Special keys: `<Enter>`, `<Tab>`, `<F3>`, `<SF6>`, `<Clear>`, …

**Approval model.** `[CmdletBinding(SupportsShouldProcess)]` with
`ConfirmImpact='High'` means interactive sessions always prompt unless
`-Confirm:$false` is passed. In addition, if `-Keys` contains any token from
`-ForbiddenKeys` (matched case-insensitively; default `<F3>`, `<F5>`, `<SF6>`,
a conservative set drawn from dealer-DMS screens where those keys save, create,
or update), a second prompt fires regardless of `-Confirm:$false`. Use `-Force`
to bypass the forbidden-key prompt, and tune the list per host and screen —
F-key meanings differ between screens even on the same system.

**Scripting note.** On Windows PowerShell 5.1, `-Confirm:$false` or `-WhatIf`
passed to *your* script does not propagate into module cmdlets it calls. Pass
`-Confirm:$false` (or `-WhatIf`) to each `Send-GsKeys` call explicitly. The
example scripts do this through an `-Unattended` switch.

Returns nothing on success. Writes an audit record either way.

---

## `Wait-GsText`

Wait for a text string to appear at a known position.

```powershell
Wait-GsText -Session <handle> -Text <string> -Row <int> -Col <int>
            [-TimeoutSeconds <int>]
```

Does **not** throw on timeout. Returns `pscustomobject` with:

| Field       | Meaning                                             |
|-------------|-----------------------------------------------------|
| Found       | `$true` if the text appeared                        |
| StatusCode  | BlueZone raw status: 0=found, 4=timeout, other=err  |
| DurationMs  | Elapsed milliseconds                                |

Example:
```powershell
$r = Wait-GsText -Session $s -Text 'Work a Quote' -Row 1 -Col 1 -TimeoutSeconds 10
if (-not $r.Found) { throw 'WAQ did not appear.' }
```

---

## `Get-GsPopup`

Enumerate open LegaSuite / embedded-browser popups.

```powershell
Get-GsPopup [-ProcessName <string>] [-UrlFilter <string>]
```

| Parameter    | Default        | Notes                                                 |
|--------------|----------------|-------------------------------------------------------|
| ProcessName  | `wsStart_4`    | GUI host process; the CDK Drive shell by default.     |
| UrlFilter    | `wipopup=true` | Regex a popup URL must match. Use `.` to match any.   |

Returns one `pscustomobject` per popup with `Title`, `Url`, `Rect`, `HWnd`,
`Document`. `Document` is the live `IHTMLDocument2` for callers who want raw
access.

Example:
```powershell
Get-GsPopup | Format-Table Title, Url
```

---

## `Read-GsPopup`

Parse a popup record into fields, buttons, and text.

```powershell
Read-GsPopup -Popup <pscustomobject> [-MaxText <int>]
# or by pipeline
Get-GsPopup | Read-GsPopup
```

Returns `pscustomobject` with:

| Field    | Shape                                                          |
|----------|----------------------------------------------------------------|
| Title    | string                                                         |
| Url      | string                                                         |
| Rect     | `{ X, Y, W, H }`                                               |
| Fields   | array of `{ Label, Id, Type, Value }`                          |
| Buttons  | string[] of button captions                                    |
| Text     | visible text, trimmed to `-MaxText` chars (default 1500)       |

Label resolution preference (highest trust first):
1. `<label for="id">` elements
2. `aria-label` attribute
3. `placeholder` attribute
4. `title` attribute
5. Nearest ancestor row's `innerText`, with hint/error elements stripped

Example:
```powershell
Get-GsPopup | Read-GsPopup | ForEach-Object {
    "$($_.Title) - $($_.Fields.Count) fields, $($_.Buttons -join ' | ')"
}
```

---

## `Write-GsAudit`

Append a workflow-level audit record. Useful for marking logical boundaries
alongside the keystroke-level records the other cmdlets write.

```powershell
Write-GsAudit -Session <handle> -Action <string>
              [-Arguments <hashtable>] [-Result <hashtable>]
              [-DurationMs <int>] [-Ok <bool>] [-ErrorMessage <string>]
              [-Cmd <string>]
```

---

## `Get-GsAuditPath` / `Set-GsAuditPath`

Read or override where the JSONL audit log goes.

```powershell
Get-GsAuditPath                             # resolves to the current effective path
Set-GsAuditPath -Path 'D:\logs\today.jsonl' # override for this PowerShell session
Set-GsAuditPath -Path $null                 # revert to the per-user default
```

Default: `%LOCALAPPDATA%\GreenScript\logs\greenscript-YYYYMMDD.jsonl`.

---

## Audit record schema

Each line in the JSONL log is one object. Fields may be omitted when not
applicable:

```json
{
  "ts":"2026-10-10T22:15:03.221Z",
  "seq":42,
  "session":"<active>",
  "cmd":"Send-GsKeys",
  "action":"send",
  "args":{"keys":"WAQ<Enter>","forbidden":[]},
  "result":{"sent":true},
  "ms":37,
  "ok":true,
  "user":"cdkuser",
  "host":"VM-DEALER-01",
  "pid":4812
}
```

`err` is present when `ok` is `false`.

`ts` is always UTC (the `Z` suffix). The default log *filename* rotates on the
workstation's local date, so late-evening entries in US time zones carry the
next day's UTC date inside a file named for the local day. `seq` restarts at 1
each time the module is imported. The `<`, `>`, `&` and `'` characters are
written literally (PowerShell 5.1 would otherwise escape them as `<` and
so on), so `Select-String '<F3>'` against the log works.
