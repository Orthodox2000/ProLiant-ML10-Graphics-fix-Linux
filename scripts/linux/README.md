# Linux scripts

| Script | Purpose | Needs root? |
|---|---|---|
| [`i915-display-fix.sh`](i915-display-fix.sh) | **Main toolkit.** `status`, `detect`, `apply`, `discover`, `revert`. Handles GRUB and systemd-boot across distros. | only for `apply`/`discover`/`revert` |
| [`i915-collect.sh`](i915-collect.sh) | Collect a full diagnostic report from the current/previous boot. | no (uses `sudo` opportunistically) |
| [`finalize-i915.sh`](finalize-i915.sh) | One-shot, non-interactive apply + recovery entry (GRUB only). | yes |

## Quick start

```bash
cd scripts/linux
chmod +x *.sh

./i915-display-fix.sh status          # inspect (read-only)
./i915-display-fix.sh detect          # find connector + mode
sudo ./i915-display-fix.sh apply      # apply permanently
sudo reboot
```

## Recover / revert

```bash
sudo ./i915-display-fix.sh revert
```

## Two-phase (unknown connector, dark screen)

```bash
sudo ./i915-display-fix.sh discover           # adds a non-destructive GRUB entry
# reboot -> "i915 DISCOVER - no nomodeset" -> then:
./i915-display-fix.sh detect
sudo ./i915-display-fix.sh apply --connector <NAME> --mode <WxH>
```

## Diagnostics

```bash
bash i915-collect.sh /tmp/i915
# -> /tmp/i915/i915-report.txt, /tmp/i915/i915-prevboot-kernel.log, EDID dumps
```

## Requirements

- `bash` 4.2+, `coreutils`, `grep`, `sed`, `findmnt`/`blkid`.
- GRUB or systemd-boot.
- Optional: `xrandr`, `glxinfo` (mesa-utils), `edid-decode` for extra detail.

## What the toolkit changes

- `/etc/default/grub` (GRUB) or `/boot/loader/entries/*.conf` (systemd-boot)
- adds `/etc/grub.d/42_i915_fix_recovery` (GRUB) — a `nomodeset` recovery entry
- backs everything up to `/var/backups/i915-display-fix/`

It **never** leaves backup files inside `/etc/grub.d/` (that would create
duplicate menu entries).
