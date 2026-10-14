# Windows scripts

Tools for Windows and **Windows Server** (2012 R2 → 2025) and Windows 10/11.
See [`docs/06-windows-server.md`](../../docs/06-windows-server.md) for the full
explanation.

| File | What it does | Needs admin? |
|---|---|---|
| `Get-GraphicsInfo.ps1` | Full inventory: adapter, driver, monitors, EDID, available modes | no |
| `Set-DisplayResolution.ps1` | List or set resolution/refresh (P/Invoke, no dependencies) | recommended |
| `Install-IntelGraphicsDriver.ps1` | Locate an extracted Intel INF and stage it with `pnputil` | yes |
| `Fix-Display.bat` | Double-click wrapper for the above | recommended |
| `DisplayFix.exe` | Native CLI (built from `src/DisplayFix.c`) | recommended |
| `src/DisplayFix.c` | Source of the `.exe` (transparent, auditable) | — |

## Quick start

```cmd
:: see what you have
Fix-Display.bat info

:: list every supported mode
Fix-Display.bat list

:: set 1366x768 (and persist it)
Fix-Display.bat set 1366 768

:: or just pick the highest mode the display reports
Fix-Display.bat best
```

## `DisplayFix.exe`

```
DisplayFix.exe                        show current mode(s)
DisplayFix.exe --list                 displays and all modes
DisplayFix.exe --current [dev]        current mode
DisplayFix.exe --modes   [dev]        list modes
DisplayFix.exe --set W H [Hz] [dev]   set a mode (persisted)
DisplayFix.exe --best    [dev]        set the highest mode
      dev = e.g. \\.\DISPLAY1   (default: primary)
```

Prebuilt binary in this folder:

- `DisplayFix.exe` — PE32+ x86-64 console executable
- **SHA-256:** `c1b8092c05b52c5a913e301c8088d1c535654602afbaf06870466304717c656e`
- Size: ~44 KB, stripped
- Built from [`src/DisplayFix.c`](src/DisplayFix.c) with mingw-w64; links only
  standard Windows libraries (`user32`, `gdi32`, `shell32`).

> The binary is **unsigned**, so SmartScreen may warn on first run. It is built
> from the source in this repository — audit it and rebuild it yourself if you
> prefer (see below). You can also skip the `.exe` entirely and use the
> PowerShell scripts, which need no compiler.

## Rebuilding the `.exe`

On Linux (Debian/Ubuntu):

```bash
sudo apt-get install -y mingw-w64
x86_64-w64-mingw32-gcc -O2 -municode -o DisplayFix.exe src/DisplayFix.c -luser32 -lgdi32 -lshell32
x86_64-w64-mingw32-strip DisplayFix.exe
```

On Windows with Visual Studio:

```cmd
cl /O2 /DUNICODE /D_UNICODE DisplayFix.c user32.lib gdi32.lib shell32.lib /Fe:DisplayFix.exe
```

On Windows with MinGW-w64:

```cmd
gcc -O2 -municode -o DisplayFix.exe DisplayFix.c -luser32 -lgdi32 -lshell32
```

## Notes

- Resolution changes made by these tools are written to the registry
  (`CDS_UPDATEREGISTRY`), so they survive a reboot.
- If Windows only reports `640x480`, the monitor’s **EDID is not being read** —
  the driver cannot see the display. Fix the cable/adapter (use an **active**
  DP→HDMI adapter); no amount of software will invent modes a display never
  reported.
- For headless servers, prefer RDP: the session resolution follows the client,
  independent of the physical adapter.
