# 7. Other operating systems

The root causes (EDID over a passive adapter; no `nomodeset` concept elsewhere)
recur on every OS. Below is what to do on the platforms people actually run on an
ML10 Gen9-class box.

---

## 7.1 FreeBSD

FreeBSD uses the **`i915kms`** kernel module (a port of the Linux driver). There is
no `nomodeset`.

```sh
# /boot/loader.conf
i915kms_load="YES"
kern.vty=vt                 # use the new vt(4) console
```

Load immediately without rebooting:

```sh
kldload i915kms
```

Check:

```sh
pciconf -lv | grep -A4 vgapci
sysctl kern.vty
dmesg | grep -i i915
```

If the monitor is not detected through the adapter, force the mode:

```sh
# after X starts, or from a script:
xrandr                 # list outputs (often HDMI-1 / DP-1)
xrandr --output HDMI-1 --mode 1366x768
```

FreeBSD has no `video=` kernel token; use an **active adapter** for reliable
detection, or an `/etc/X11/xorg.conf.d/` `PreferredMode` stanza as in Linux.

A helper is provided: [`scripts/freebsd/i915-freebsd.sh`](../scripts/freebsd/i915-freebsd.sh).

---

## 7.2 Proxmox VE / Debian hypervisor

Proxmox is Debian under the hood → the **Linux fix applies directly**:

```bash
sudo ./scripts/linux/i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
sudo reboot
```

If the host is headless, the local console barely matters; the fix is mainly so
the boot console and any local login are usable.

---

## 7.3 VMware ESXi

ESXi is a hypervisor, not a desktop. The integrated GPU is not used; ESXi runs a
VGA/EFI framebuffer at low resolution for its DCUI (“yellow console”). This is by
design — you manage ESXi over the network (Host Client / vSphere).

- If the DCUI is unreadable through an adapter, add an **active adapter** or use
  IPMI/remote management.
- Passing the iGPU to a VM (GTV-d / Intel GVT-g) is not supported on Skylake P530
  in ESXi’s standard tooling; use a discrete GPU for that.

---

## 7.4 TrueNAS SCALE / CORE, Unraid, OMV

All are Linux:

- **TrueNAS SCALE / Unraid / OMV** (Debian/RHEL-derived): run the Linux toolkit.
  On TrueNAS SCALE the root filesystem is managed, but kernel parameters can be
  added via the UI (System → Advanced → **Kernel command line / sysctl**) or
  `/etc/default/grub` + `update-grub` from a shell.
- **TrueNAS CORE** (FreeBSD): follow §7.1.

For appliance-style NAS boxes with no keyboard/video session, the practical fix is
again the **active adapter**.

---

## 7.5 pfSense / OPNsense (FreeBSD)

Same as FreeBSD (§7.1): load `i915kms`, and force the mode if needed. These
router images are usually headless; the console is only used once.

---

## 7.6 illumos / OpenIndiana / SmartOS

Intel KMS support is limited/experimental. On Skylake P530 expect the generic VGA
framebuffer. Use an active adapter, and drive the machine over the network. Not a
supported display target.

---

## 7.7 ChromeOS Flex / other Linux appliances

ChromeOS Flex uses the standard Intel graphics stack. Boot parameters are not
user-editable in the usual way; rely on the **active adapter**.

---

## 7.8 Dual-boot / multi-OS on the same machine

Because the fix is per-OS, you can run Linux (fixed via kernel line) and
Windows/Server (fixed via driver + adapter) side by side on the ML10 Gen9. The
**active adapter** benefits every OS at once and is the recommended baseline.

---

## 7.9 Summary table

| OS | Mechanism | Best fix |
|---|---|---|
| Linux (any distro) | `i915` + `video=` on kernel cmdline | This repo’s toolkit |
| Windows / Server | Intel WDDM driver | Driver + **active adapter** |
| FreeBSD / pfSense / TrueNAS CORE | `i915kms` | `i915kms_load=YES` (+ active adapter) |
| Proxmox / TrueNAS SCALE / Unraid | Linux | Linux toolkit |
| ESXi | hypervisor framebuffer only | Manage over network; active adapter for DCUI |
| illumos | limited KMS | active adapter, manage over network |
