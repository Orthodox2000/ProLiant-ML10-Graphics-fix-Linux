# QUICKSTART

The 60‑second version. Full detail lives in [`docs/`](docs/) and
[`README.md`](README.md).

---

## What this fixes

HP ProLiant **ML10 Gen9** (Intel **HD Graphics P530**) shows **no signal / black
screen**, or is stuck at a fixed 1024×768, when the monitor is connected through
the motherboard's **DisplayPort** via a **DP → DVI → HDMI** adapter.

**Cause:** the passive adapter hides the monitor's EDID, so the driver never
enables the output. `nomodeset` "works" only by abandoning the GPU entirely.

---

## Linux — 3 commands

```bash
cd scripts/linux
./i915-display-fix.sh detect                 # tells you the connector + mode
sudo ./i915-display-fix.sh apply             # applies it permanently
sudo reboot
```

If the screen is **dark right now** and you don't know the connector name:

```bash
sudo ./i915-display-fix.sh discover          # adds a safe "no nomodeset" GRUB entry
sudo reboot                                  # pick "i915 DISCOVER" at the menu
./i915-display-fix.sh detect                 # then apply with what it prints
```

Verify after rebooting:

```bash
./i915-display-fix.sh status
```

Revert any time:

```bash
sudo ./i915-display-fix.sh revert
```

---

## The raw kernel parameters (any distro)

Remove `nomodeset`; add these to the kernel command line:

```
i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e
```

- Replace **`HDMI-A-1`** with your connector (`DP-1` if the monitor is native DP).
- Replace **`1366x768`** with your monitor's native resolution.
- Keep the trailing **`e`** (force-enable even when "disconnected").
- **Never** force both `DP-1` and `HDMI-A-1` — they are the *same* physical port.

Per‑distro regeneration: see [`docs/05-distro-guide.md`](docs/05-distro-guide.md).

---

## Windows / Windows Server

There is no kernel command line — install the **Intel graphics driver** and, if
the monitor still isn't detected, use an **active** DP→HDMI adapter.

```cmd
Fix-Display.bat info          :: are you on the Basic Display Adapter?
Fix-Display.bat list          :: supported modes
Fix-Display.bat set 1366 768  :: set + persist a mode
Fix-Display.bat best          :: highest mode the display reports
```

Full guide: [`docs/06-windows-server.md`](docs/06-windows-server.md).

---

## Other OSes

| OS | Quick fix |
|---|---|
| FreeBSD / pfSense / TrueNAS CORE | `i915kms_load="YES"` in `/boot/loader.conf` ([script](scripts/freebsd/i915-freebsd.sh)) |
| Proxmox / TrueNAS SCALE / Unraid | Linux fix above |
| VMware ESXi | manage over the network (no iGPU driver) |

Details: [`docs/07-other-os.md`](docs/07-other-os.md).

---

## Always works: the hardware fix

A **passive** DP→HDMI/DVI plug cannot pass EDID. An **active** one can, and then
Linux, Windows and FreeBSD all just work — no software changes needed.
See [`docs/08-hardware-cables-adapters.md`](docs/08-hardware-cables-adapters.md).

---

## Install the toolkit system‑wide (optional)

```bash
sudo ./install.sh        # installs to /usr/local/sbin
sudo i915-display-fix status
```

## Need help?

- Still dark → [`docs/09-troubleshooting.md`](docs/09-troubleshooting.md)
- Prove it worked → [`docs/10-verification.md`](docs/10-verification.md)
- Collect a report to share → `bash scripts/linux/i915-collect.sh /tmp/i915`
