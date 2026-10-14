#!/usr/bin/env bash
#
# finalize-i915.sh — one-shot, non-interactive application of the i915 display
# fix + a nomodeset recovery entry, on a GRUB system.
#
# For advanced control (systemd-boot, discovery, dry-run, revert) use
#   i915-display-fix.sh
#
# Usage:
#   sudo bash finalize-i915.sh [connector] [WxH]
#   (defaults: auto-detect the connected connector, mode 1366x768)
#
# Example:
#   sudo bash finalize-i915.sh HDMI-A-1 1366x768
set -euo pipefail

CONNECTOR="${1:-}"
MODE="${2:-1366x768}"
BACKUP_DIR="/var/backups/i915-display-fix"
PARAMS="i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0"

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0 [connector] [WxH]" >&2; exit 1; }

if [ -z "$CONNECTOR" ]; then
  for f in /sys/class/drm/card[0-9]*-*/status; do
    [ -e "$f" ] || continue
    if [ "$(cat "$f")" = connected ]; then
      n=$(basename "$(dirname "$f")"); CONNECTOR="${n#card[0-9]-}"; break
    fi
  done
fi
[ -n "$CONNECTOR" ] || { echo "No connected connector found; pass one explicitly." >&2; exit 1; }

VIDEO="video=${CONNECTOR}:${MODE}@60e"
KREL=$(uname -r)
UUID=$(findmnt -no UUID /)
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "connector : $CONNECTOR"
echo "mode      : $MODE"
echo "video     : $VIDEO"

cp -a /etc/default/grub "$BACKUP_DIR/grub.default.$TS.bak"

# Replace the default cmdline: drop nomodeset, keep everything else, add params.
CUR=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | head -1 \
        | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
NEW=""
for t in $CUR; do
  [ "$t" = "nomodeset" ] && continue
  case "$t" in video=*) continue;; esac
  NEW="$NEW $t"
done
NEW=$(echo "$NEW $PARAMS $VIDEO" | xargs)
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW\"|" /etc/default/grub
grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub \
  && sed -i 's|^GRUB_TIMEOUT_STYLE=.*|GRUB_TIMEOUT_STYLE=menu|' /etc/default/grub \
  || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
grep -q '^GRUB_TIMEOUT=' /etc/default/grub \
  && sed -i 's|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=10|' /etc/default/grub \
  || echo 'GRUB_TIMEOUT=10' >> /etc/default/grub

# Recovery entry (nomodeset)
cat > /etc/grub.d/42_i915_fix_recovery <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry "i915 fix - Recovery (nomodeset, basic graphics)" --class gnu-linux --class os {
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
chmod 755 /etc/grub.d/42_i915_fix_recovery

if command -v update-grub >/dev/null 2>&1; then
  update-grub
elif command -v grub2-mkconfig >/dev/null 2>&1; then
  grub2-mkconfig -o /boot/grub2/grub.cfg
else
  grub-mkconfig -o /boot/grub/grub.cfg
fi

echo
echo "Done. New default kernel line:"
grep -m1 'linux.*root=UUID' /boot/grub*/grub.cfg | sed 's/^/  /' || true
echo
echo "Reboot to apply. Revert with: sudo bash $(dirname "$0")/i915-display-fix.sh revert"
