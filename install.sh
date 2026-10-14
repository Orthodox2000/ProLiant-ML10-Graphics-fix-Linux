#!/usr/bin/env bash
#
# install.sh - install the Linux toolkit into /usr/local/sbin.
#
# Usage:
#   sudo ./install.sh            # install
#   sudo ./install.sh --uninstall
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
SBINDIR="$PREFIX/sbin"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" = "--uninstall" ]; then
  [ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
  rm -f "$SBINDIR/i915-display-fix" "$SBINDIR/i915-collect"
  echo "Removed from $SBINDIR."
  exit 0
fi

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./install.sh" >&2; exit 1; }

install -d "$SBINDIR"
install -m 0755 "$HERE/scripts/linux/i915-display-fix.sh" "$SBINDIR/i915-display-fix"
install -m 0755 "$HERE/scripts/linux/i915-collect.sh"     "$SBINDIR/i915-collect"

echo "Installed:"
echo "  $SBINDIR/i915-display-fix"
echo "  $SBINDIR/i915-collect"
echo
echo "Try:  sudo i915-display-fix status"
echo "      sudo i915-display-fix detect"
echo "      sudo i915-display-fix apply"
