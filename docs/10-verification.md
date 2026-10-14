# 10. Verification

How to prove the fix worked, per platform. Run these after rebooting into the
fixed configuration.

---

## 10.1 Linux — one-liners

```bash
# 1. Kernel: nomodeset is gone, the video= token is present
cat /proc/cmdline

# 2. The real driver is loaded
grep -qw i915 /proc/modules && echo "i915 OK" || echo "i915 MISSING"

# 3. The connector is connected and enabled at the right mode
for c in /sys/class/drm/*/status; do
  d=$(dirname "$c")
  echo "$(basename "$d"): $(cat "$c") enabled=$(cat "$d/enabled") mode=$(head -1 "$d/modes")"
done

# 4. Xorg sees it at the right resolution
xrandr | grep connected

# 5. Hardware acceleration (not llvmpipe)
glxinfo | grep -E 'OpenGL renderer|direct rendering'
```

Expected (reference machine):

```
HDMI-A-1: connected enabled=enabled mode=1366x768
HDMI-1 connected primary 1366x768+0+0
OpenGL renderer string: Mesa Intel(R) HD Graphics P530 (SKL GT2)
direct rendering: Yes
```

Or simply:

```bash
./scripts/linux/i915-display-fix.sh status
```

### Automated pass/fail check

```bash
# fails loudly if nomodeset is still present or i915 is missing
! grep -qw nomodeset /proc/cmdline && grep -qw i915 /proc/modules \
  && echo "PASS" || echo "FAIL"
```

---

## 10.2 Finding your native resolution

```bash
# Preferred (first) mode the monitor advertises:
cat /sys/class/drm/card*-HDMI-A-1/modes | head -1

# Everything it supports:
cat /sys/class/drm/card*-HDMI-A-1/modes

# The raw EDID (decode with edid-decode if installed):
ls -l /sys/class/drm/card*-HDMI-A-1/edid
edid-decode /sys/class/drm/card*-HDMI-A-1/edid | grep -i preferred -A2
```

The first mode in `modes` is the monitor’s preferred/native mode — use it in the
`video=` token.

---

## 10.3 Windows / Server

```powershell
Get-CimInstance Win32_VideoController |
  Select-Object Name, DriverVersion, CurrentHorizontalResolution,
                CurrentVerticalResolution, CurrentRefreshRate

# confirm it is not the basic adapter:
Get-PnpDevice -Class Display | Format-Table Status, FriendlyName, InstanceId
```

Good: `Intel(R) HD Graphics ...` at your native resolution, not
`Microsoft Basic Display Adapter`.

The provided tools:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\Get-GraphicsInfo.ps1
DisplayFix.exe --current
```

---

## 10.4 FreeBSD

```sh
sysctl kern.vty                       # should say vt
kldstat | grep i915kms
pciconf -lv | grep -A4 vgapci
# under X:
xrandr | grep connected
```

---

## 10.5 Performance sanity check

A properly driven display has hardware acceleration. If `glxinfo` says
`llvmpipe` (Linux) or Windows shows the Basic Display Adapter, the fix is *not*
complete even if the resolution looks right.

```bash
# Linux: should NOT say llvmpipe / softpipe
glxinfo | grep -i 'renderer'

# Quick OpenGL capability
glxinfo | grep 'OpenGL version'
```

---

## 10.6 What “success” looks like

| Check | Expected |
|---|---|
| `/proc/cmdline` | no `nomodeset`; has `video=<connector>:<WxH>@<Hz>e` |
| Driver | `i915` loaded (Linux) / Intel driver (Windows) |
| Connector | exactly one `connected`, `enabled` |
| Current mode | monitor’s native resolution |
| Renderer | Intel GPU, hardware accelerated |
| Stability | no flicker / blanking over several minutes idle |
