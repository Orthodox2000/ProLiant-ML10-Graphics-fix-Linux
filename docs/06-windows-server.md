# 6. Windows Server & Windows (10/11)

Windows does not use a kernel command line, so the Linux fix does not apply. The
same machine, cable chain and failure show up differently here, and the solution
is a combination of **driver** and **hardware** work.

---

## 6.1 Why Windows Server shows no/ugly video on this box

1. **Windows Server ships a generic driver.** Until a real graphics driver is
   installed, Windows uses the **Microsoft Basic Display Adapter**
   (`msbasicdisplay`). That adapter:
   - ignores most of the GPU,
   - caps the mode list to what the firmware/EDID provides,
   - with a **passive DP→DVI→HDMI chain that hides EDID**, often leaves you at
     **640×480 or 1024×768**.

2. **Intel does not officially support consumer iGPUs on Windows Server.** There
   is no SKU of the HD Graphics P530 driver labelled “Windows Server 2022”.
   The **Windows 10/11 64-bit** driver can usually still be installed manually
   (“Have Disk”), but you must bypass the compatibility check.

3. **The same EDID problem as Linux.** The DP++ port is fine, but a passive
   adapter can drop the DDC channel, so Windows cannot read the monitor. This is
   the root of “640×480 only” and “no signal”.

> Practical consequence: on Windows the **single most effective fix is an
> *active* DisplayPort adapter** (see
> [08-hardware-cables-adapters.md](08-hardware-cables-adapters.md)). Driver
> installation gets you acceleration and correct modes; the adapter fixes
> detection.

---

## 6.2 Solution A — install the Intel graphics driver (recommended first step)

### What you need

| Item | Value |
|---|---|
| GPU | Intel HD Graphics **P530**, `VEN_8086&DEV_191D` |
| Last Windows 10/11 x64 driver for Skylake (Gen9) | Intel **15.45.x** series, e.g. `15.45.34.5174`, INF name `igdlh64.inf` |
| Alternative | Intel **DCH** driver `31.0.101.x` (Skylake support is limited/vendor-specific) |
| HP option | Search HP support for “ML10 Gen9 Intel Graphics” SoftPaq (may cover Win Server 2012 R2/2016) |

This is a **standard INF/`pnputil` driver install** — the same mechanism as any
other Windows disk or device driver — so it works on Windows 10/11 and Windows
Server 2012 R2 → 2025, GUI *or* command line, attended *or* unattended.

### Method 1 — Device Manager “Have Disk” (works on Server 2016/2019/2022)

1. Download and **extract** the Intel driver package (`.exe` → run it and let it
   extract to `C:\SWSetup\...`, or use 7-Zip; the `.inf` files are in a
   subfolder such as `Graphics`).
2. `Device Manager` → **Display adapters** → *Microsoft Basic Display Adapter* →
   **Update driver** → **Browse my computer** → **Let me pick from a list** →
   **Have Disk…**
3. Point to `igdlh64.inf` in the extracted folder.
4. Choose **Intel(R) HD Graphics P530** (or 530) and accept the compatibility
   warning.
5. Reboot. Verify:

```powershell
Get-CimInstance Win32_VideoController |
  Select-Object Name, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution
```
You want `Intel(R) HD Graphics ...` and your native resolution, not
`Microsoft Basic Display Adapter`.

> If the INF refuses to install on Server 2022/2025 because of the OS version,
> either (a) use the Windows 10/11 driver of the *same WDDM generation*, or
> (b) temporarily enable **test signing** / driver signature enforcement
> bypass, install, then re-enable. Prefer (a).

### Method 2 — `pnputil` (scriptable, no GUI)

```powershell
# Stage and install the INF (admin PowerShell):
pnputil /add-driver "C:\Drivers\Intel\Graphics\igdlh64.inf" /install
# If it installs as a package but does not bind:
pnputil /enum-drivers | Select-String -Context 0,4 igdlh
# then assign it in Device Manager, or:
Get-PnpDevice -Class Display | Enable-PnpDevice -Confirm:$false
```

`scripts/windows/Install-IntelGraphicsDriver.ps1` automates the staging and
points out the manual Device Manager step if binding is refused. Two
one-click/scriptable entry points ship with it:

```cmd
:: double-click wrapper: auto-elevates and auto-detects the extracted driver
scripts\windows\Install-IntelGraphicsDriver.bat

:: or via the general wrapper (install / drivers subcommands)
Fix-Display.bat install
Fix-Display.bat install C:\SWSetup\Intel\Graphics
Fix-Display.bat drivers

:: scriptable, no GUI — suitable for unattended installs / Server Core
powershell -ExecutionPolicy Bypass -File Install-IntelGraphicsDriver.ps1 -Path C:\SWSetup\Intel\Graphics
```

If you omit `-Path`, the script searches the usual extraction locations
(`%SystemDrive%\SWSetup\Intel*`, `%SystemDrive%\Drivers\Intel*`, `Downloads`,
the current folder). Like any `pnputil` driver, this can be driven from
`unattend.xml`, an imaging task sequence, or a login script.

### Method 3 — HP SoftPaq

HP occasionally publishes a Windows Server graphics driver for the ML10 Gen9
(usually for Server 2012 R2/2016). Check HP support by serial number; if it
exists it installs cleanly with no compatibility hacks.

---

## 6.3 Solution B — fix detection (the EDID problem)

Even with the right driver, a passive adapter can leave Windows unable to read
the monitor. In order of preference:

1. **Use an active DP adapter** (see §6.4). This is the real fix and also helps
   Linux.
2. **Force a mode in the registry.** Windows stores display configuration under:

   ```
   HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration
   ```

   Each subkey holds a `PrimSurfSize.cx` / `PrimSurfSize.cy` and per-monitor
   `ActiveSize.cx` / `.cy`. Setting them to `1366` / `768` and rebooting will make
   Windows *try* that mode (it only sticks if the adapter/EDID allows it). Back up
   the key first. This is a workaround, not a guarantee.
3. **Set the mode at logon** with a script (see §6.5). Works when the mode exists
   in the list but Windows picks a lower one.

---

## 6.4 Solution C — hardware: the active adapter

HP documents that the ML10 Gen9 DisplayPorts expect an **active** DP adapter.
Active adapters contain a level-shifter/converter chip (DisplayPort → TMDS) and
regenerate DDC, so both Windows and Linux see a proper monitor.

Buy one of:

- **Active DP → HDMI** (the cleanest: one cable), or
- **Active DP → DVI**, then a DVI→HDMI cable.

Look for the words **“active”** / “DP++ to HDMI active” in the product listing.
A passive “DP to HDMI” plug has no chip and will reproduce this exact bug.

See [08-hardware-cables-adapters.md](08-hardware-cables-adapters.md) for details
and alternatives.

---

## 6.5 Registry / PowerShell resolution control

### Built-in (some Server versions)

```powershell
Get-DisplayResolution           # if the cmdlet exists
Set-DisplayResolution -Width 1366 -Height 768
```
(These cmdlets exist on Server Core in several Server releases; if `Get-Command`
cannot find them, use the next method.)

### Portable (works on every Windows / Server)

Use the provided scripts:

```powershell
# inventory: GPU, driver, monitors, and every mode each output supports
powershell -ExecutionPolicy Bypass -File scripts\windows\Get-GraphicsInfo.ps1

# list modes, then set one (uses ChangeDisplaySettingsEx via P/Invoke)
powershell -ExecutionPolicy Bypass -File scripts\windows\Set-DisplayResolution.ps1 -List
powershell -ExecutionPolicy Bypass -File scripts\windows\Set-DisplayResolution.ps1 -Width 1366 -Height 768
```

Or the tiny native tool (see §6.6):

```cmd
DisplayFix.exe --list
DisplayFix.exe --set 1366 768
DisplayFix.exe --best
```

### Third-party CLIs (if you prefer)

- **QRes** (Anders Kjersem): `QRes.exe /x:1366 /y:768`
- **NirCmd** (NirSoft): `nircmd.exe setdisplay 1366 768 32`
- **DisplayChanger** (12noon): `dc64.exe -width=1366 -height=768`

These are convenient for logon scripts / Task Scheduler “At log on”.

---

## 6.6 The `DisplayFix.exe` native tool

Because a native binary is handy for logon scripts, unattended setups and
Server Core, this repo includes its **source** and a build recipe:

```
scripts/windows/src/DisplayFix.c      # ~200 lines, Win32 only, no dependencies
```

Features:
- `--list` — enumerate adapters and every supported mode.
- `--set W H [Hz] [device]` — apply a mode and persist it (`CDS_UPDATEREGISTRY`).
- `--best [Hz] [device]` — pick the highest mode the adapter reports.
- `--current` — print the active mode.

### Build it (on any Linux with mingw-w64)

```bash
sudo apt-get install -y mingw-w64        # Debian/Ubuntu
make windows                              # produces scripts/windows/DisplayFix.exe
```

or directly:

```bash
x86_64-w64-mingw32-gcc -O2 -municode -o DisplayFix.exe src/DisplayFix.c -lgdi32 -luser32
```

### Build it on Windows

```cmd
:: With Visual Studio (Developer Command Prompt):
cl /O2 /DUNICODE /D_UNICODE DisplayFix.c user32.lib gdi32.lib /Fe:DisplayFix.exe
:: With MinGW-w64 for Windows:
gcc -O2 -municode -o DisplayFix.exe DisplayFix.c -lgdi32 -luser32
```

> The repository ships the source; a pre-built binary may or may not be present
> depending on whether it was built (see `scripts/windows/README.md`). If absent,
> build it with the two commands above, or just use the PowerShell scripts, which
> need no compiler.

---

## 6.7 Headless / remote servers

If the ML10 runs as a headless server, the physical console mode is mostly
irrelevant — use **RDP**, which renders at the client’s resolution regardless of
the local adapter:

- Enable: `Server Manager → Local Server → Remote Desktop`, or
  ```powershell
  Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
  Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
  ```
- For a server with **no desktop experience** and no GPU driver, RDP still gives
  you a usable desktop at your chosen size.

---

## 6.8 Windows 10 / 11 (workstation)

Simpler than Server:

1. Let **Windows Update** install a graphics driver, or run the Intel
   **Driver & Support Assistant**.
2. If the monitor is not detected through a passive adapter, install an **active
   DP adapter**.
3. Resolution: *Settings → System → Display*, or `DisplayFix.exe --best`.

Windows 10/11 have full WDDM support and hardware acceleration for the P530 with
the 15.45 or newer driver.

---

## 6.9 Windows checklist

- [ ] Confirm `Ven_8086&Dev_191D` is present (Device Manager → Details → Hardware Ids).
- [ ] Install a real Intel driver (no more “Microsoft Basic Display Adapter”).
- [ ] Confirm EDID is read (monitor shows a name in Display settings, not “Generic PnP Monitor”).
- [ ] If not, replace the passive adapter with an **active** one.
- [ ] Pin the resolution (Display settings / script / `DisplayFix.exe`).
- [ ] For unattended servers, prefer RDP and ignore the physical console.
