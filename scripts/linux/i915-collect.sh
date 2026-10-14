#!/usr/bin/env bash
#
# i915-collect.sh — gather display/i915 diagnostics into a single report.
#
# Usage:  bash i915-collect.sh [output-dir]
# Default output dir: current directory.
#
# Produces:
#   i915-report.txt            human-readable summary
#   i915-prevboot-kernel.log   kernel log of the previous boot (if available)
#   i915-edid-*.bin            raw EDID of each connected connector
#
# Safe: read-only. Uses sudo only for journal/dmidecode (optional).

set -uo pipefail

OUT="${1:-$PWD}"
mkdir -p "$OUT"
REPORT="$OUT/i915-report.txt"
PREVLOG="$OUT/i915-prevboot-kernel.log"

have() { command -v "$1" >/dev/null 2>&1; }

section() { printf '\n===== %s =====\n' "$*"; }

{
  section "Report generated"
  date -Is
  echo "host: $(hostname)"
  echo "kernel: $(uname -r)"
  echo "distro: $( . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" )"

  section "Kernel command line"
  cat /proc/cmdline

  section "CPU"
  have lscpu && lscpu | sed -n '1,14p'

  section "System (DMI)"
  if have dmidecode; then
    dmidecode -s system-product-name 2>/dev/null || sudo -n dmidecode -s system-product-name 2>/dev/null
    dmidecode -s baseboard-product-name 2>/dev/null || true
    dmidecode -s bios-version 2>/dev/null || true
  fi

  section "GPU (lspci)"
  have lspci && lspci -nnk 2>/dev/null | grep -A3 -iE 'vga|display|3d'

  section "i915 module loaded?"
  if grep -qw '^i915' /proc/modules 2>/dev/null; then
    echo "yes"
    grep '^i915' /proc/modules
  else
    echo "NO  (nomodeset active, or no Intel GPU)"
  fi

  section "simpledrm / framebuffer"
  lsmod 2>/dev/null | grep -E 'simpledrm|drm' || true

  section "DRM connectors"
  for c in /sys/class/drm/*/status; do
    [ -e "$c" ] || continue
    d=$(dirname "$c")
    name=$(basename "$d")
    printf '%-24s status=%-13s enabled=%-9s mode=%s\n' \
      "$name" "$(cat "$c" 2>/dev/null)" \
      "$(cat "$d/enabled" 2>/dev/null)" \
      "$(head -1 "$d/modes" 2>/dev/null)"
  done

  section "Supported modes per connector"
  for m in /sys/class/drm/card*/modes; do
    [ -e "$m" ] || continue
    echo "-- $(dirname "$m" | xargs basename) --"
    head -20 "$m"
  done

  section "Raw EDID files"
  for e in /sys/class/drm/card*-*/edid; do
    [ -e "$e" ] || continue
    d=$(dirname "$e")
    name=$(basename "$d")
    if [ -s "$e" ]; then
      echo "$name: EDID present ($(wc -c <"$e") bytes) -> $OUT/i915-edid-$name.bin"
      cat "$e" > "$OUT/i915-edid-$name.bin" 2>/dev/null || true
    else
      echo "$name: no EDID (0 bytes)"
    fi
  done

  section "xrandr"
  have xrandr && xrandr 2>/dev/null

  section "OpenGL renderer"
  if have glxinfo; then
    glxinfo 2>/dev/null | grep -E 'OpenGL (renderer|version)|direct rendering'
  else
    echo "(glxinfo not installed)"
  fi

  section "i915 module parameters (non-default only)"
  for p in /sys/module/i915/parameters/*; do
    [ -e "$p" ] || continue
    printf '%s=%s\n' "$(basename "$p")" "$(cat "$p" 2>/dev/null)"
  done

  section "Recent i915/drm kernel messages (this boot)"
  journalctl -b -k --no-pager 2>/dev/null \
    | grep -iE 'i915|drm|edid|GMBUS|connector' \
    | tail -80 || true

  section "Boot list"
  journalctl --list-boots 2>/dev/null | tail -10 || true
} > "$REPORT" 2>&1

# Previous boot kernel log (best effort)
{
  echo "# Previous boot kernel log (journalctl -b -1 -k)"
  echo "# If empty, boot again once and re-run so a previous boot exists."
  journalctl -b -1 -k --no-pager 2>/dev/null || echo "(no previous boot in journal)"
} > "$PREVLOG" 2>&1

echo "Wrote:"
echo "  $REPORT"
echo "  $PREVLOG"
echo
echo "Send the report (and the prevboot log) to whoever is helping you."
echo "Nothing here is secret, but review it before posting publicly."
