# 4. Linux solution (the fix)

This document is the canonical, step-by-step procedure. It assumes GRUB (the
default on Ubuntu/Mint/Debian/Fedora/Arch/openSUSE); systemd-boot and
distro-specific commands are in [05-distro-guide.md](05-distro-guide.md).

> **Two ways to run it:** the automated toolkit
> ([`scripts/linux/i915-display-fix.sh`](../scripts/linux/i915-display-fix.sh)),
> or the manual steps below. Both do exactly the same thing.

---

## 4.1 Automated (recommended)

```bash
cd scripts/linux
chmod +x i915-display-fix.sh

# 1. Inspect the current state (read-only, safe):
./i915-display-fix.sh status

# 2. If i915 is running, it can tell you the connector + mode:
./i915-display-fix.sh detect
#    -> "Apply it with: sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768"

# 3. Preview, then apply:
sudo ./i915-display-fix.sh apply --dry-run
sudo ./i915-display-fix.sh apply

# 4. Reboot (do NOT touch the menu; it auto-boots the fixed entry):
sudo reboot
```

If the machine is currently dark and you do not know the connector name, use the
two-phase workflow in [09-troubleshooting.md](09-troubleshooting.md#93-a-the-screen-is-dark-and-i-dont-know-the-connector-name).

---

## 4.2 Manual (GRUB) — the exact steps

### Step 1 — Find the connector name

If you can already boot to a desktop with `nomodeset`, you still cannot see the
real connector name (only `Unknown-1` from `simpledrm`). The reliable way is to
boot once **without** `nomodeset` and read the state, even if the screen is dark:

```bash
# after booting without nomodeset, over SSH or a second console:
for c in /sys/class/drm/*/status; do
  echo "$(basename "$(dirname "$c")"): $(cat "$c")"
done
```

You want the connector whose status is `connected` — typically `HDMI-A-1` or
`DP-1`. (If nothing is `connected`, see the discover workflow.)

### Step 2 — Edit `/etc/default/grub`

```bash
sudo cp -a /etc/default/grub /etc/default/grub.bak-$(date +%Y%m%d-%H%M%S)
sudo nano /etc/default/grub
```

Change the line:

```diff
-GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"
+GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e"
```

Notes:

- Delete `nomodeset`.
- `HDMI-A-1` → your connector name from Step 1.
- `1366x768` → your monitor’s native resolution (see
  [10-verification.md](10-verification.md#102-finding-your-native-resolution)).
- Keep the `e` suffix (force-enable even if “disconnected”).

Optional, to make the menu visible long enough to reach a recovery entry:

```diff
+GRUB_TIMEOUT_STYLE=menu
+GRUB_TIMEOUT=10
```

### Step 3 — Regenerate the GRUB config

Debian/Ubuntu/Mint:

```bash
sudo update-grub
```

Fedora/RHEL/openSUSE:

```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

Arch:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Step 4 — Add a recovery entry (strongly recommended)

Create `/etc/grub.d/42_i915_fix_recovery` (mode `0755`) so you always have a
one-keystroke way back to a working 1024×768 desktop:

```bash
KREL=$(uname -r)
UUID=$(findmnt -no UUID /)
sudo tee /etc/grub.d/42_i915_fix_recovery >/dev/null <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry "Recovery - safe graphics (nomodeset)" --class gnu-linux --class os {
    recordfail
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --no-floppy --fs-uuid --set=root $UUID
    linux  /boot/vmlinuz-$KREL root=UUID=$UUID ro quiet splash nomodeset
    initrd /boot/initrd.img-$KREL
}
EOF
sudo chmod 755 /etc/grub.d/42_i915_fix_recovery
sudo update-grub
```

> ⚠️ **Never** leave `*.bak` copies inside `/etc/grub.d/`. GRUB executes every
> executable file in that directory, and a backup containing a `menuentry` line
> becomes a **duplicate menu entry**. Keep backups in `/root/` or
> `/var/backups/`.

### Step 5 — Reboot and verify

```bash
sudo reboot
# after it comes back:
cat /proc/cmdline
xrandr | grep connected         # expect "<name> connected primary 1366x768+0+0"
```

---

## 4.3 What each parameter does

| Parameter | Effect | Why it is here |
|---|---|---|
| *(remove)* `nomodeset` | Lets `i915` bind | **The** essential change |
| `video=HDMI-A-1:1366x768@60e` | Force-enable connector + mode | Works around missing EDID |
| `i915.enable_dc=0` | Disable display C-states | Skylake analog power glitches |
| `i915.enable_psr=0` | Disable Panel Self Refresh | No panel here; avoids blanking |
| `i915.enable_fbc=0` | Disable frame-buffer compression | Avoids flicker on adapters |
| `i915.enable_dp_mst=0` | Disable DP Multi-Stream | No MST hub; simplifies link setup |
| `i915.disable_power_well=0` | Keep power wells always on | Maximum stability |

Only `nomodeset`-removal and the `video=` token are strictly required in most
cases. The `i915.*` flags are belt-and-braces stability; drop them if you prefer
default power behaviour and it still works.

---

## 4.4 Reverting

```bash
sudo cp -a /etc/default/grub.bak-<timestamp> /etc/default/grub
sudo rm -f /etc/grub.d/42_i915_fix_recovery
sudo update-grub
sudo reboot
```

Or with the toolkit:

```bash
sudo ./i915-display-fix.sh revert
```

---

## 4.5 Changing the resolution later

Temporarily (current session):

```bash
xrandr --output HDMI-1 --mode 1366x768
```

Permanently: change `1366x768` in the `video=` token and re-run Step 3, or add an
Xorg configuration / a desktop startup command (see
[05-distro-guide.md](05-distro-guide.md#persisting-the-resolution-in-x)).
