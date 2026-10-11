# Compatibility — what greenscript can drive

`greenscript` talks to a **terminal emulator** running on a Windows
workstation. It never talks to the host system directly. So compatibility is
a question in two parts: is the emulator supported, and is the host something
people use through that emulator?

## Emulators

| Emulator                                                      | Session types it displays         | greenscript status                                                        |
|---------------------------------------------------------------|-----------------------------------|---------------------------------------------------------------------------|
| Rocket BlueZone                                               | 3270, 5250, VT100/220/420, 6530   | **Supported** — `BZWhll.WhllObj` COM driver (v0.1)                        |
| IBM Personal Communications (PCOMM)                           | 3270, 5250, VT                    | Planned — HLLAPI driver                                                   |
| Reflection Desktop (incl. former Attachmate / Micro Focus editions) | 3270, 5250, VT, 6530        | Planned — HLLAPI driver                                                   |
| Extra! X-treme                                                | 3270, 5250, VT                    | Planned — HLLAPI driver                                                   |
| Rumba+                                                        | 3270, 5250, VT, 6530              | Planned — HLLAPI driver                                                   |
| HostExplorer                                                  | 3270, 5250, VT                    | Planned — HLLAPI driver                                                   |
| Any other emulator exposing EHLLAPI (`ehlapi32.dll` / `ehlapi64.dll`) | varies                    | Planned — HLLAPI driver                                                   |

The HLLAPI driver targets the IBM EHLLAPI specification — the same interface
Microsoft Power Automate Desktop's terminal-emulation actions use — so once it
lands, the emulator column above becomes "anything that implements EHLLAPI".

Two further surfaces are emulator-independent:

- **GUI faceplate popups.** LegaSuite-style shells render host-launched
  dialogs in embedded Internet Explorer controls. `Get-GsPopup` and
  `Read-GsPopup` read those through `IHTMLDocument2`, regardless of which
  emulator sits underneath.
- **Print capture and SFTP** (planned). Many hosts "print" reports to the
  emulator's print queue or expose a file-transfer path; capturing those is
  often cleaner than reading formatted screens.

## Host systems

The hosts below are commonly accessed through one of the emulators above.
Listing a system here means exactly that and nothing more — no endorsement,
no partnership, no claim that its vendor supports third-party automation.
Check your own license terms. `greenscript` has been verified live only
against **CDK Drive** (see the README's *Verification status*); everything
else is "same kind of thing".

### Automotive retail

- CDK Drive (dealer management system; BlueZone client with LegaSuite GUI
  faceplates) — the system this project was built against.
- Other dealer management systems with terminal heritage.

### Banking and credit unions

- Jack Henry SilverLake, CU*BASE, and other IBM i (5250) cores.
- FIS Systematics and other z/OS (3270, CICS) cores.
- Loan servicing, item processing, and wire-room applications that never left
  the green screen even where the core did.

### Insurance

- Policy administration, claims, and billing on z/OS (CICS / IMS).
- RPG applications on IBM i at regional carriers and MGAs.

### Healthcare

- The VA's VistA and the Indian Health Service's RPMS "roll-and-scroll"
  interfaces (MUMPS applications used through a terminal).
- Legacy laboratory, pharmacy, and patient-accounting systems.

### Government

- State unemployment insurance, DMV, Medicaid (MMIS), and tax systems.
- Court case-management and child-support enforcement systems.
- Federal benefit and records systems with 3270 front ends.

### Distribution, manufacturing, ERP

- JD Edwards World (IBM i).
- Infor XA (formerly MAPICS) and Infor LX (formerly BPCS).
- VAI S2K and other IBM i ERP packages.
- Epicor Eclipse and other UniVerse / UniData / MultiValue applications
  (Rocket, which makes BlueZone, also owns those databases).
- Older warehouse-management systems such as Manhattan PkMS.

### Retail

- Merchandising and back-office systems on IBM i, such as Island Pacific.
- Store-polling and inventory systems that still present 5250 screens.

### Travel and logistics

- TPF-based airline reservation, cargo, and crew systems with native
  terminal entry.
- Rail, freight, and customs-brokerage legacy systems.

### Utilities and telecom

- Customer information systems (CIS) and billing on the mainframe.
- Outage and work-order systems with 3270 or VT front ends.

## Is my system a fit?

Say yes to all five and `greenscript` applies:

1. Your users launch a terminal emulator (BlueZone today; PCOMM, Reflection,
   Extra!, Rumba, HostExplorer once the HLLAPI driver lands) to use the
   system.
2. The screens are a fixed character grid — 24×80 or 27×132 — with fields at
   known row and column positions and function keys driving navigation.
3. The emulator has a macro recorder or scripting menu. If a person can
   record a macro against the session, `greenscript` can drive the same
   session.
4. Each user signs in with their own credentials, and the automation will
   run under those credentials on that user's workstation.
5. You can name the screen headers and key sequences for the workflow you
   want to automate (the examples show the pattern).

For 132-column sessions pass `-Cols 132` to `Connect-GsSession`.

## What it is not a fit for

- Browser-based or Windows-GUI-only applications. The one exception is the
  LegaSuite-style popup pattern covered by `Read-GsPopup`.
- Systems that offer a supported API for what you want to do. Use the API;
  screen automation is for the work no API covers.
- Emulators that expose neither a COM automation object nor EHLLAPI. These
  are rare, but they exist.
- Anything that needs the automation to run somewhere other than the user's
  own workstation, under credentials that are not the user's own.
