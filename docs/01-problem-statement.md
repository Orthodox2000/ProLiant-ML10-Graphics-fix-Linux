# 1. Problem statement

## 1.1 Summary

On an **HPE ProLiant ML10 Gen9** with the onboard **Intel HD Graphics P530**
(`8086:191d`), a monitor connected through the motherboard's **DisplayPort** —
in practice nearly always via a **DP → DVI → HDMI** or **DP → HDMI** adapter —
does not produce a picture under a normal Linux graphics stack.

Two distinct behaviours are reported:

| Configuration | Result |
|---|---|
| `nomodeset` on the kernel command line (the “safe” default) | Boots to a **fixed 1024×768** desktop. No GPU acceleration. Resolution cannot be changed in software. |
| `nomodeset` removed (“normal” boot) | **Black screen / “no signal”** from the motherboard. Sometimes a dark mouse cursor flickers in a corner. |
| Windows Server / Windows | Often **no display at all** after driver install, or a “generic” 640×480 desktop. |

## 1.2 Why people hit this

The ML10 Gen9 motherboard exposes **two DisplayPort 1.2** connectors and **no
HDMI/DVI/VGA**. The overwhelming majority of monitors in this price bracket are
HDMI. So the realistic chain is:

```
[motherboard DP] ──► [DP→DVI plug] ──► [DVI→HDMI cable] ──► [monitor HDMI]
```

At least three things are wrong with that chain on this hardware:

1. **`nomodeset` is not a resolution fix** — it disables kernel mode-setting
   entirely, leaving you with the firmware’s fixed framebuffer.
2. **EDID (the monitor’s “capabilities chip”) is not passed reliably** through
   cheap passive adapters, so the driver cannot see that a monitor is attached.
3. On Intel, a **dual-mode (“DP++”) port appears twice**: once under its DP name
   (`DP-1`) and once under its HDMI name (`HDMI-A-1`). Force-enabling the wrong
   one, or both, makes the driver fight itself.

## 1.3 Scope of this repository

In scope:

- Every Linux distribution we can cover with a bootloader-based fix (GRUB and
  systemd-boot), including per-distro commands.
- Windows Server 2012 R2 → 2025 and Windows 10/11.
- FreeBSD and the common virtualisation/“NAS” platforms.
- Hardware alternatives (active adapters, KVMs, alternative connectors).

Out of scope (documented only):

- Reflashing the BIOS/firmware.
- Adding a discrete GPU.
- Multi-monitor tiling edge cases.

## 1.4 Reference hardware (used for every measurement here)

| Item | Value |
|---|---|
| System | HPE ProLiant ML10 Gen9 (`ML10Gen9`), BIOS 1.010 |
| CPU | Intel Xeon E3-1225 v5 @ 3.30 GHz (4 cores, VT-x) |
| iGPU | Intel HD Graphics **P530**, PCI `8086:191d`, subsystem `8086:2212` |
| Display outputs | 2 × DisplayPort 1.2 (DP++ capable, per VBT) |
| Display | 1366×768 monitor on HDMI |
| Cable chain | DP → DVI plug → DVI→HDMI cable → monitor |
| OS (reference) | Linux Mint 22.3, kernel 7.0.0-38-generic, Mesa 25.x |
| Other kernels tested | 6.14-generic (RHEL/Debian-style naming irrelevant) |

Raw captures live in [`../examples/`](../examples/).
