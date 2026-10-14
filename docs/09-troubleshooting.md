# 9. Troubleshooting

Work top to bottom. Almost every “still dark” case is one of: `nomodeset` still
present, wrong connector name, wrong mode, or a passive adapter.

---

## 9.1 Quick checks

```bash
cat /proc/cmdline                     # is nomodeset gone? is video=<name>:<mode>e there?
grep -qw i915 /proc/modules           # is i915 loaded?
for c in /sys/class/drm/*/status; do echo "$(basename "$(dirname "$c")"): $(cat "$c")"; done
xrandr | grep connected
journalctl -k -b | grep -iE 'i915.*(fail|error|WARN)' | grep -vi AUX
```

---

## 9.2 Symptom → cause → fix

| Symptom | Likely cause | Fix |
|---|---|---|
| `modprobe i915` → “No such device”; only `simpledrm` | `nomodeset` still on the cmdline | Remove it, reboot (see [04](04-linux-solution.md)) |
| “No signal” / monitor sleeps, nothing at all | Connector not force-enabled, EDID missed | Add `video=<correct-name>:<mode>e` |
| Signal present, **black screen, cursor flickers** | You forced **both** `DP-x` and `HDMI-A-x` (same port) | Force **only** the one matching the cable |
| Picture but 1024×768 / 640×480 | Mode not forced; firmware framebuffer in use | Force the native mode; check `xrandr` |
| Correct on one boot, wrong on the next | EDID/bit-bang race at boot | Keep the `e` suffix; consider an active adapter |
| Works at login screen, goes black after login | Desktop picked a bad mode/scale | Pin the mode (`xrandr`/Xorg/autostart) |
| `i915` loads, no connector `connected` | EDID not read at all (passive adapter) | Use `discover`, then an **active** adapter |
| Wrong resolution only in the installer/live USB | Live images may default to `nomodeset` | Add the same `video=` token to the boot menu (`e` to edit, or `Tab`) |
| Flicker / random blanks at idle | Skylake power features | Keep `i915.enable_dc=0 enable_psr=0 enable_fbc=0` |
| Second monitor not detected | Only one DDI active, or MST misconfig | Enable the right second connector; keep `enable_dp_mst=0` for a hub-free setup |

---

## 9.3 (a) The screen is dark and I don’t know the connector name

This is the “chicken and egg” case: you cannot read `/sys/class/drm` names until
`i915` is running, but you cannot see anything when it is.

### Option 1 — SSH (best)

Before rebooting, enable SSH so you can log in while the screen is dark:

```bash
sudo systemctl enable --now ssh
# note the IP:
ip -brief addr
```

Then boot without `nomodeset` (or use the toolkit’s `discover` entry) and, from
another machine:

```bash
ssh you@<ip> 'for c in /sys/class/drm/*/status; do echo "$(basename "$(dirname "$c")"): $(cat "$c")"; done'
```

Whatever is `connected` is your connector name.

### Option 2 — the toolkit’s discover entry

```bash
sudo ./i915-display-fix.sh discover            # adds a non-destructive GRUB entry
# reboot, pick "i915 DISCOVER - no nomodeset"
./i915-display-fix.sh detect                   # prints the connector + apply command
```

If even that stays dark, try:

```bash
sudo ./i915-display-fix.sh discover --force-all
```

`--force-all` force-enables every candidate port. It may still be black (multi
connector conflict), but it lets you SSH in and read which connector reports
`connected`/has an EDID. Then apply with that single connector.

### Option 3 — guess from the port

If your cable is in the **left** DP port, try `HDMI-A-1` first; the **right** port,
try `HDMI-A-2`. You can pass both as separate attempts, rebooting between.

---

## 9.4 (b) “Signal but black screen, cursor flashes”

You are forcing two names for one port. Remove the `video=` tokens and keep only
the one matching the cable:

```diff
-video=DP-1:1366x768@60e video=HDMI-A-1:1366x768@60e
+video=HDMI-A-1:1366x768@60e
```

Confirm in the log:

```bash
journalctl -b -1 -k | grep -i "handle_conflicting_encoders"
```

---

## 9.5 (c) Wrong resolution

Find the native mode:

```bash
xrandr                       # look at the '*' (current) and the list for the connected output
# or, without a desktop:
cat /sys/class/drm/card*-HDMI-A-1/modes | head
```

Set it live, then make it permanent:

```bash
xrandr --output HDMI-1 --mode 1366x768          # live test
# permanent: change the number in video=HDMI-A-1:1366x768@60e and re-run update-grub
```

---

## 9.6 (d) Recovery when the screen stays black

1. **Power-cycle.** The GRUB menu (if it appears) lets you pick
   *“Recovery - safe graphics (nomodeset)”* or the distro’s *recovery mode*.
2. If you cannot see the menu at all, force the recovery entry:
   - At the GRUB menu, press `e`, append `nomodeset` to the `linux` line,
     `Ctrl-X`/`F10` to boot.
3. Once in, revert:

```bash
sudo ./i915-display-fix.sh revert
sudo reboot
```

4. Last resort: boot a live USB and edit `/etc/default/grub` on the installed
   system (mount the root partition, edit, chroot or just edit the file, then
   regenerate GRUB).

---

## 9.7 Diagnostic cheat-sheet

```bash
# GPU + driver
lspci -nnk | grep -A3 -iE 'vga|display'
# Kernel + cmdline
uname -r; cat /proc/cmdline
# Module state
grep -w i915 /proc/modules || echo "i915 not loaded"
# Connectors
for c in /sys/class/drm/*/status; do echo "$(basename "$(dirname "$c")"): $(cat "$c")"; done
# Modes per connector
cat /sys/class/drm/card*-HDMI-A-1/modes
# EDID presence
ls -l /sys/class/drm/card*-HDMI-A-1/edid
# Full DRM debug (verbose; needs drm.debug=0x1e on the cmdline)
journalctl -b -k | grep -iE 'i915|drm' | less
```

The automated collector is
[`scripts/linux/i915-collect.sh`](../scripts/linux/i915-collect.sh).

---

## 9.8 Harmless log noise (do not chase)

```
intel_hdmi_set_edid: HDMI GMBUS EDID read failed, retry using GPIO bit-banging
failed to retrieve link info, disabling eDP
PSR condition failed: Port not supported
Reserved GGTT:[...] for use by error capture
```
These mean: EDID came in over bit-banging, there is no internal panel, and PSR
isn’t applicable. They are expected on this hardware.
