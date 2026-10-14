# 11. Reference

## 11.1 Kernel command line parameters used

| Parameter | Values | Meaning |
|---|---|---|
| `nomodeset` | *(presence)* | Blocks DRM/KMS drivers (sets `video_firmware_drivers_only()`). **Remove it.** |
| `video=<conn>:<WxH>[@Hz][e]` | see §11.2 | Force-enable an output and its mode. |
| `i915.enable_dc=` | `0`/`1`/`2` | Display C-states (DC5/DC6). `0` = off (stable). |
| `i915.enable_psr=` | `0`/`1` | Panel Self Refresh. `0` = off. |
| `i915.enable_fbc=` | `0`/`1` | Frame Buffer Compression. `0` = off. |
| `i915.enable_dp_mst=` | `0`/`1` | DP Multi-Stream Transport. `0` = off. |
| `i915.disable_power_well=` | `0`/`1`/`-1` | `0` = keep power wells always on. |
| `drm.debug=` | hex bitmask | DRM debug categories (see §11.4). |
| `log_buf_len=` | e.g. `16M` | Enlarge the kernel log ring (for verbose debug). |
| `quiet` | — | Suppress most boot messages. |
| `splash` | — | Graphical boot splash. |

## 11.2 `video=` syntax in full

```
video=<connector>:<xres>x<yres>[@<refresh>][<options>]
```

- `<connector>` — DRM connector name: `DP-1`, `HDMI-A-1`, `eDP-1`, `VGA-1`, …
  Use the name from `/sys/class/drm/`.
- `<refresh>` — optional vertical refresh in Hz, e.g. `@60`.
- `<options>` — one or more of:

  | Suffix | Meaning |
  |---|---|
  | `e` | Force-enable the output even if the driver thinks it is disconnected. **This is the key suffix for this bug.** |
  | `d` | Force-**disable** the output. |
  | `D` | Enable with **digital** (TMDS) signalling — useful to force an HDMI/DVI encoder. |
  | `m` | Use mode with margins. |
  | `i` | Interlaced. |

Examples:

```
video=HDMI-A-1:1366x768@60e      # force 1366x768@60 on HDMI-A-1, even if "disconnected"
video=DP-1:d                     # force-disable DP-1
video=HDMI-A-1:1920x1080@60eD    # force digital + 1080p
```

You can list several `video=` tokens, but **do not** force both names of the same
physical port (see [03](03-root-cause.md)).

## 11.3 Connector name ↔ X output name

| DRM (kernel) | Xorg (`xrandr`) | Type |
|---|---|---|
| `HDMI-A-1` | `HDMI-1` | HDMI/DP++ in TMDS mode |
| `DP-1` | `DP-1` | native DisplayPort |
| `eDP-1` | `eDP-1` | internal panel |
| `VGA-1` | `VGA-1` | analog |

`HDMI-A-2`, `DP-2`, … correspond to the next physical port.

## 11.4 `drm.debug` bitmask

| Bit | Category |
|---|---|
| `0x01` | `DRM_UT_CORE` |
| `0x02` | `DRM_UT_DRIVER` |
| `0x04` | `DRM_UT_KMS` (connector/EDID/modeset — the useful one) |
| `0x08` | `DRM_UT_PRIME` |
| `0x10` | `DRM_UT_ATOMIC` |
| `0x1e` | DRIVER+KMS+PRIME+ATOMIC (what this repo used) |

Debug messages are rate-limited and verbose; turn them off (remove `drm.debug`)
once you are done.

## 11.5 Useful commands

```bash
# DRM state
cat /sys/class/drm/card*-*/status
cat /sys/class/drm/card*-*/modes
cat /sys/class/drm/card*-*/enabled

# Xorg
xrandr --verbose
xrandr --output HDMI-1 --mode 1366x768 --rate 60
cvt 1366 768 60              # generate a modeline
gtf 1366 768 60

# Kernel / module
modinfo i915
for p in /sys/module/i915/parameters/*; do echo "$(basename $p)=$(cat $p)"; done

# Boot
bootctl status                # systemd-boot
grub-mkconfig -o /boot/grub/grub.cfg
```

## 11.6 Glossary

| Term | Meaning |
|---|---|
| **KMS** | Kernel Mode Setting — the kernel programs the display controller. |
| **i915** | Linux kernel driver for Intel integrated graphics. |
| **nomodeset** | Kernel flag that disables KMS; leaves the firmware framebuffer. |
| **EDID** | Monitor capability block read over DDC/I²C. |
| **DDC / DDC-CI** | Display Data Channel (the I²C bus carrying EDID). |
| **GMBUS** | Intel’s hardware I²C controller for DDC. |
| **Bit-banging** | Software-toggling the DDC lines when GMBUS fails (slow). |
| **DP++** | Dual-mode DisplayPort: can output native DP or TMDS (HDMI/DVI). |
| **DDI** | Digital Display Interface — the physical Intel display port block. |
| **DDC** | see above |
| **CRTC** | Display controller / scanout pipe. |
| **PHY** | The electrical layer of a display port. |
| **PSR** | Panel Self Refresh (power saving). |
| **FBC** | Frame Buffer Compression. |
| **MST** | Multi-Stream Transport (daisy-chaining DP displays). |
| **DCH** | Declarative Componentized Hardware — modern Windows driver model. |
| **WDDM** | Windows Display Driver Model. |

## 11.7 File locations (Linux)

| Path | Purpose |
|---|---|
| `/etc/default/grub` | GRUB defaults (edit here) |
| `/boot/grub/grub.cfg` | generated GRUB (Debian/Arch) |
| `/boot/grub2/grub.cfg` | generated GRUB (Fedora/openSUSE) |
| `/etc/grub.d/` | scripts that generate menu entries (never put backups here) |
| `/boot/loader/entries/*.conf` | systemd-boot entries |
| `/sys/class/drm/` | live connector state |
| `/var/backups/i915-display-fix/` | backups made by this repo’s toolkit |
| `/etc/X11/xorg.conf.d/` | Xorg snippets (mode pinning) |
