#!/usr/bin/env bash
#
# i915-freebsd.sh - set up i915kms on FreeBSD and (optionally) force a mode.
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
# Run as root:  sudo sh i915-freebsd.sh [connector] [WxH]
#
# What it does:
#   1. Adds i915kms_load="YES" and kern.vty=vt to /boot/loader.conf (backed up).
#   2. Loads i915kms now (kldload) if possible.
#   3. Prints current connector state.
#
# It does NOT install X or set xorg.conf automatically; see docs/07-other-os.md.
set -e

LOADER_CONF=/boot/loader.conf
TS=$(date +%Y%m%d-%H%M%S)

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }

echo "== backing up $LOADER_CONF =="
cp -a "$LOADER_CONF" "$LOADER_CONF.bak-$TS"

echo "== enabling i915kms + vt console =="
grep -q '^i915kms_load=' "$LOADER_CONF" 2>/dev/null \
  || echo 'i915kms_load="YES"' >> "$LOADER_CONF"
grep -q '^kern.vty=' "$LOADER_CONF" 2>/dev/null \
  || echo 'kern.vty=vt' >> "$LOADER_CONF"

echo "== loading module now =="
kldload i915kms 2>/dev/null && echo "i915kms loaded" || echo "(already loaded or not loadable now; a reboot will load it)"
kldstat | grep -i i915 || true

echo
echo "== PCs / connector state =="
pciconf -lv 2>/dev/null | grep -A4 vgapci || true

echo
echo "== X outputs (if an X server is running) =="
if command -v xrandr >/dev/null 2>&1; then
  xrandr 2>/dev/null | grep -E 'connected|Screen' || echo "(no X display)"
else
  echo "(xrandr not installed; install x11/xrandr)"
fi

if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
  echo
  echo "== forcing ${2:-} on ${1:-} via xrandr =="
  xrandr --output "$1" --mode "$2" || echo "(xrandr failed; see docs)"
fi

echo
echo "Done. Reboot to be sure the module loads from loader.conf."
echo "Revert: cp -a $LOADER_CONF.bak-$TS $LOADER_CONF && reboot"
