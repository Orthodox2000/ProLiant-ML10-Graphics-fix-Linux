#!/usr/bin/env bash
#
# i915-display-fix.sh — portable, persistent fix for Intel i915 displays that
# stay dark because of "nomodeset" and/or unreliable EDID through a
# DP/DVI/HDMI adapter chain.
#
# Sub-commands:
#   status                 Show current display / i915 state (read-only)
#   detect                 Detect the connected connector + preferred mode
#   apply [options]        Apply the fix persistently (per bootloader)
#   discover [--force-all] Add a NON-destructive GRUB entry to probe connectors
#   revert                 Undo everything (restore backups)
#
# apply options:
#   --connector NAME       e.g. HDMI-A-1, DP-1  (default: auto-detect)
#   --mode WxH             e.g. 1366x768        (default: preferred/first)
#   --refresh N            default 60
#   --no-force             do NOT add a video= token (only drop nomodeset)
#   --dry-run              print what would change, change nothing
#
# Supports: GRUB (Debian/Ubuntu/Mint, Fedora/RHEL/Rocky/Alma, Arch/Manjaro,
#           openSUSE/SLES) and systemd-boot. Other bootloaders -> manual notes.
#
# License: public domain / do-what-you-want. No warranty.
set -euo pipefail

VERSION="1.0.0"
BACKUP_DIR="/var/backups/i915-display-fix"
# Conservative Skylake-era stability flags (all harmless on desktop/server).
CONSERVATIVE_PARAMS=(
  "i915.enable_dc=0"
  "i915.enable_psr=0"
  "i915.enable_fbc=0"
  "i915.enable_dp_mst=0"
  "i915.disable_power_well=0"
)
DISCOVER_ENTRY="/etc/grub.d/41_i915_discover"
RECOVERY_ENTRY="/etc/grub.d/42_i915_fix_recovery"

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_info=$'\033[36m'; c_off=$'\033[0m'
[ -t 1 ] || { c_ok=; c_warn=; c_err=; c_info=; c_off=; }

log()  { printf '%s[*]%s %s\n'  "$c_info" "$c_off" "$*"; }
ok()   { printf '%s[+]%s %s\n'  "$c_ok"   "$c_off" "$*"; }
warn() { printf '%s[!]%s %s\n'  "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%s[x]%s %s\n'  "$c_err"  "$c_off" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "This action needs root. Re-run with: sudo $0 $*"
}

is_i915_loaded() { grep -qw '^i915' /proc/modules 2>/dev/null; }

# ---------------------------------------------------------------------------
# environment detection
# ---------------------------------------------------------------------------
distro_pretty() {
  ( . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}" ) || echo unknown
}

# Sets globals: GRUB_TOOL (regen cmd), GRUB_CFG (path), BOOTLOADER
detect_bootloader() {
  BOOTLOADER="unknown"; GRUB_TOOL=""; GRUB_CFG=""; SB_DIR=""

  local cfg
  for cfg in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
    if [ -f "$cfg" ]; then GRUB_CFG="$cfg"; BOOTLOADER="grub"; break; fi
  done

  if command -v update-grub >/dev/null 2>&1 && [ -f /etc/default/grub ]; then
    GRUB_TOOL="update-grub"; GRUB_CFG="${GRUB_CFG:-/boot/grub/grub.cfg}"; BOOTLOADER="grub"
  elif command -v grub2-mkconfig >/dev/null 2>&1 && [ -f /etc/default/grub ]; then
    GRUB_TOOL="grub2-mkconfig"; GRUB_CFG="${GRUB_CFG:-/boot/grub2/grub.cfg}"; BOOTLOADER="grub"
  elif command -v grub-mkconfig >/dev/null 2>&1 && [ -f /etc/default/grub ]; then
    GRUB_TOOL="grub-mkconfig"; GRUB_CFG="${GRUB_CFG:-/boot/grub/grub.cfg}"; BOOTLOADER="grub"
  fi

  if [ "$BOOTLOADER" = unknown ]; then
    local d
    for d in /boot/loader/entries /boot/efi/loader/entries /efi/loader/entries; do
      if [ -d "$d" ]; then SB_DIR="$d"; BOOTLOADER="systemd-boot"; break; fi
    done
  fi
  if [ "$BOOTLOADER" = unknown ]; then BOOTLOADER="manual"; fi
  return 0
}

grub_regen() {
  case "$GRUB_TOOL" in
    update-grub)    update-grub ;;
    grub2-mkconfig) grub2-mkconfig -o "$GRUB_CFG" ;;
    grub-mkconfig)  grub-mkconfig  -o "$GRUB_CFG" ;;
    *) die "No GRUB regeneration tool found." ;;
  esac
}

# Print "NAME|status|first-mode" for every real DRM connector.
drm_connectors() {
  local f dir name status mode
  for f in /sys/class/drm/card[0-9]*-*/status; do
    [ -e "$f" ] || continue
    dir=$(dirname "$f")
    name=$(basename "$dir"); name=${name#card[0-9]-}
    case "$name" in
      Unknown-*|card[0-9]*) continue ;;   # skip simpledrm pseudo-connectors
    esac
    status=$(cat "$f" 2>/dev/null || echo unknown)
    mode=$(head -1 "$dir/modes" 2>/dev/null || true)
    printf '%s|%s|%s\n' "$name" "$status" "$mode"
  done
}

first_connected_connector() {
  local line n s m
  while IFS='|' read -r n s m; do
    if [ "$s" = connected ]; then printf '%s|%s\n' "$n" "$m"; return 0; fi
  done < <(drm_connectors)
  return 1
}

root_uuid() {
  findmnt -no UUID / 2>/dev/null || \
  blkid -s UUID -o value "$(findmnt -no SOURCE / 2>/dev/null)" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# token rewriting (used by both GRUB and systemd-boot)
# ---------------------------------------------------------------------------
# Reads existing tokens from $1, drops nomodeset + old connector video= forces,
# adds conservative params and (unless --no-force) the video= token.
# Globals honoured: FORCE_TOKEN, NO_FORCE
array_contains() {
  local needle="$1"; shift
  local x
  for x in "$@"; do
    if [ "$x" = "$needle" ]; then return 0; fi
  done
  return 1
}

rewrite_tokens() {
  local -a toks=() new=()
  local t p
  read -r -a toks <<< "$1"
  for t in "${toks[@]}"; do
    case "$t" in
      nomodeset) continue ;;
      video=DP-*|video=HDMI-*|video=eDP-*|video=VGA-*|video=DVI-*|video=DSI-*|video=LVDS-*) continue ;;
    esac
    new+=("$t")
  done
  for p in "${CONSERVATIVE_PARAMS[@]}"; do
    if ! array_contains "$p" ${new[@]+"${new[@]}"}; then new+=("$p"); fi
  done
  if [ "${NO_FORCE:-0}" -eq 0 ] && [ -n "${FORCE_TOKEN:-}" ]; then
    new+=("$FORCE_TOKEN")
  fi
  if [ "${#new[@]}" -gt 0 ]; then printf '%s' "${new[*]}"; fi
  return 0
}

# ---------------------------------------------------------------------------
# status / detect
# ---------------------------------------------------------------------------
cmd_status() {
  echo "OS              : $(distro_pretty)"
  echo "Kernel          : $(uname -r)"
  echo "Command line    : $(cat /proc/cmdline)"
  echo "i915 loaded     : $(is_i915_loaded && echo yes || echo 'no (nomodeset? reboot needed)')"
  detect_bootloader
  echo "Bootloader      : $BOOTLOADER${GRUB_TOOL:+ ($GRUB_TOOL)}"
  echo
  echo "DRM connectors:"
  local line
  while IFS='|' read -r n s m; do printf '  %-12s %-13s %s\n' "$n" "$s" "$m"; done < <(drm_connectors)
  if have xrandr; then
    echo; echo "xrandr:"
    xrandr 2>/dev/null | sed -n '1p;/connected/p' | sed 's/^/  /'
  fi
  if have glxinfo; then
    echo; glxinfo 2>/dev/null | grep -E 'OpenGL renderer' | sed 's/^/  /' || true
  fi
}

cmd_detect() {
  detect_bootloader
  local pick name mode
  if ! is_i915_loaded; then
    warn "i915 is NOT loaded (nomodeset active, or no Intel GPU)."
    warn "Boot once WITHOUT nomodeset first, then run 'detect' again."
    warn "See README 'Two-phase workflow'."
    return 1
  fi
  if ! pick=$(first_connected_connector); then
    die "No connected DRM connector found. Check the cable/adapter (HP DP ports need an active dongle)."
  fi
  name="${pick%%|*}"; mode="${pick##*|}"
  # The panel in the original case is 1366x768; note it if available.
  local mf
  for mf in /sys/class/drm/card*-"$name"/modes; do
    if [ -f "$mf" ] && grep -qx '1366x768' "$mf"; then
      echo "Note: this display also offers 1366x768."
      break
    fi
  done
  echo "Connected connector : $name"
  echo "Preferred/first mode: $mode"
  echo
  echo "Apply it with:"
  echo "  sudo $0 apply --connector $name --mode ${mode:-1366x768}"
}

# ---------------------------------------------------------------------------
# apply
# ---------------------------------------------------------------------------
fixup_default_grub() {
  local cur new line
  cur=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
  new=$(rewrite_tokens "$cur")
  line="GRUB_CMDLINE_LINUX_DEFAULT=\"$new\""
  if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$line|" /etc/default/grub
  else
    printf '%s\n' "$line" >> /etc/default/grub
  fi
  # Make sure a menu is actually shown so a recovery entry is reachable.
  grep -qE '^GRUB_TIMEOUT_STYLE=' /etc/default/grub && \
    sed -i 's|^GRUB_TIMEOUT_STYLE=.*|GRUB_TIMEOUT_STYLE=menu|' /etc/default/grub || \
    echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
  if grep -qE '^GRUB_TIMEOUT=' /etc/default/grub; then
    sed -i 's|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=10|' /etc/default/grub
  else
    echo 'GRUB_TIMEOUT=10' >> /etc/default/grub
  fi
  ok "Updated /etc/default/grub"
}

write_grub_recovery_entry() {
  local krel vmlinuz initrd uuid
  krel=$(uname -r); uuid=$(root_uuid)
  vmlinuz=""; initrd=""
  for p in "/boot/vmlinuz-$krel" "/boot/vmlinuz-linux"; do
    if [ -f "$p" ]; then vmlinuz="$p"; break; fi
  done
  for p in "/boot/initrd.img-$krel" "/boot/initramfs-$krel.img" "/boot/initramfs-linux.img" "/boot/initrd-$krel"; do
    if [ -f "$p" ]; then initrd="$p"; break; fi
  done
  if [ -z "$vmlinuz" ] || [ -z "$initrd" ] || [ -z "$uuid" ]; then
    warn "Could not determine kernel/initrd/root UUID; skipping custom recovery entry."
    warn "Use your distro's built-in 'recovery mode' GRUB entry instead."
    return 0
  fi
  cat > "$RECOVERY_ENTRY" <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry "i915 fix - Recovery (nomodeset, basic graphics)" --class gnu-linux --class os {
    recordfail
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --no-floppy --fs-uuid --set=root $uuid
    linux  $vmlinuz root=UUID=$uuid ro quiet splash nomodeset
    initrd $initrd
}
EOF
  chmod +x "$RECOVERY_ENTRY"
  ok "Wrote recovery entry: $RECOVERY_ENTRY"
}

fixup_systemd_boot() {
  local f def
  def=""
  if [ -f /boot/loader/loader.conf ]; then def=$(awk '/^default/{print $2}' /boot/loader/loader.conf); fi
  local entries=()
  for f in "$SB_DIR"/*.conf; do
    if [ -e "$f" ]; then entries+=("$f"); fi
  done
  [ "${#entries[@]}" -gt 0 ] || die "No systemd-boot entries in $SB_DIR"
  for f in "${entries[@]}"; do
    if [ -n "$def" ] && [ "$(basename "$f" .conf)" != "$def" ]; then continue; fi
    local cur new
    cur=$(sed -n 's/^options //p' "$f")
    new=$(rewrite_tokens "$cur")
    sed -i "s|^options .*|options $new|" "$f"
    ok "Updated $f"
  done
  return 0
}

cmd_apply() {
  local connector="" mode="" refresh=60
  NO_FORCE=0; FORCE_TOKEN=""; local dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --connector) connector="${2:?}"; shift 2 ;;
      --mode)      mode="${2:?}"; shift 2 ;;
      --refresh)   refresh="${2:?}"; shift 2 ;;
      --no-force)  NO_FORCE=1; shift ;;
      --dry-run)   dry=1; shift ;;
      *) die "Unknown apply option: $1" ;;
    esac
  done

  detect_bootloader

  if [ "$NO_FORCE" -eq 0 ] && [ -z "$connector" ]; then
    if is_i915_loaded; then
      local pick; pick=$(first_connected_connector) || die "No connected connector; pass --connector explicitly."
      connector="${pick%%|*}"; [ -z "$mode" ] && mode="${pick##*|}"
    else
      die "i915 not loaded, cannot auto-detect. Pass --connector and --mode, or run 'discover' first."
    fi
  fi
  if [ "$NO_FORCE" -eq 0 ]; then
    [ -n "$mode" ] || die "No mode known; pass --mode WxH (e.g. 1366x768)."
    FORCE_TOKEN="video=${connector}:${mode}@${refresh}e"
    log "Will force: $FORCE_TOKEN"
  else
    log "Will NOT force a connector (only removing nomodeset)."
  fi

  if [ "$dry" -eq 1 ]; then
    echo
    echo "--- DRY RUN ---"
    echo "Bootloader : $BOOTLOADER"
    if [ "$BOOTLOADER" = grub ]; then
      local cur; cur=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
      echo "New cmdline: $(rewrite_tokens "$cur")"
    fi
    echo "Recovery   : $RECOVERY_ENTRY (GRUB only)"
    return 0
  fi

  need_root "$@"
  mkdir -p "$BACKUP_DIR"
  local ts; ts=$(date +%Y%m%d-%H%M%S)

  case "$BOOTLOADER" in
    grub)
      cp -a /etc/default/grub "$BACKUP_DIR/grub.default.$ts.bak"
      fixup_default_grub
      write_grub_recovery_entry
      log "Regenerating GRUB ($GRUB_TOOL -> $GRUB_CFG) ..."
      grub_regen
      ok "GRUB updated."
      echo
      echo "Default kernel line now:"
      grep -m1 "linux.*root=UUID" "$GRUB_CFG" | sed 's/^/  /' || true
      ;;
    systemd-boot)
      local f
      for f in "$SB_DIR"/*.conf; do
        if [ -e "$f" ]; then cp -a "$f" "$BACKUP_DIR/$(basename "$f").$ts.bak"; fi
      done
      fixup_systemd_boot
      ok "systemd-boot entries updated."
      ;;
    *)
      warn "Unsupported/unknown bootloader."
      echo "Manual step: remove 'nomodeset' from your kernel command line and add:"
      echo "  ${CONSERVATIVE_PARAMS[*]} $FORCE_TOKEN"
      ;;
  esac

  echo
  ok "Done. Reboot to apply."
  echo "If the screen stays dark, pick the recovery entry ('i915 fix - Recovery')"
  echo "or your distro's 'recovery mode' entry, then run: $0 revert"
}

# ---------------------------------------------------------------------------
# discover (non-destructive GRUB entry to probe connectors)
# ---------------------------------------------------------------------------
cmd_discover() {
  local force_all=0
  if [ "${1:-}" = "--force-all" ]; then force_all=1; fi
  need_root "$@"
  detect_bootloader
  [ "$BOOTLOADER" = grub ] || die "discover currently supports GRUB only."

  local krel vmlinuz initrd uuid params
  krel=$(uname -r); uuid=$(root_uuid)
  vmlinuz=""; initrd=""
  for p in "/boot/vmlinuz-$krel" "/boot/vmlinuz-linux"; do
    if [ -f "$p" ]; then vmlinuz="$p"; break; fi
  done
  for p in "/boot/initrd.img-$krel" "/boot/initramfs-$krel.img" "/boot/initramfs-linux.img" "/boot/initrd-$krel"; do
    if [ -f "$p" ]; then initrd="$p"; break; fi
  done
  [ -n "$vmlinuz" ] && [ -n "$initrd" ] && [ -n "$uuid" ] || die "Cannot locate kernel/initrd/root UUID."
  params="quiet splash log_buf_len=16M drm.debug=0x1e ${CONSERVATIVE_PARAMS[*]}"
  if [ "$force_all" -eq 1 ]; then
    local c
    for c in DP-1 DP-2 DP-3 DP-4 HDMI-A-1 HDMI-A-2 HDMI-A-3 HDMI-A-4; do
      params="$params video=$c:1366x768@60e"
    done
  fi

  cat > "$DISCOVER_ENTRY" <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry "i915 DISCOVER - no nomodeset (diagnostics)" --class gnu-linux --class os {
    recordfail
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    search --no-floppy --fs-uuid --set=root $uuid
    linux  $vmlinuz root=UUID=$uuid ro $params
    initrd $initrd
}
EOF
  chmod +x "$DISCOVER_ENTRY"
  grub_regen
  ok "Added discover entry; GRUB regenerated."
  echo "Reboot, pick 'i915 DISCOVER - no nomodeset', then run:  $0 detect"
  echo "(If the screen is dark, log in over SSH / a serial console.)"
}

# ---------------------------------------------------------------------------
# revert
# ---------------------------------------------------------------------------
cmd_revert() {
  need_root "$@"
  detect_bootloader
  rm -f "$DISCOVER_ENTRY" "$RECOVERY_ENTRY"
  local latest
  latest=$(ls -1t "$BACKUP_DIR"/grub.default.*.bak 2>/dev/null | head -1 || true)
  if [ -n "$latest" ]; then
    cp -a "$latest" /etc/default/grub
    ok "Restored /etc/default/grub from $latest"
  else
    warn "No /etc/default/grub backup found; leaving the command line as-is."
  fi
  if [ "$BOOTLOADER" = grub ] && [ -n "$GRUB_TOOL" ]; then
    grub_regen
    ok "GRUB regenerated."
  elif [ "$BOOTLOADER" = systemd-boot ]; then
    local b; b=$(ls -1t "$BACKUP_DIR"/*.conf.*.bak 2>/dev/null | head -1 || true)
    if [ -n "$b" ]; then
      warn "systemd-boot: restore the entries manually from $BACKUP_DIR,"
      warn "or run 'apply' again with the desired settings."
    fi
  fi
  echo "Revert complete. Reboot to return to the previous configuration."
  return 0
}

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    status)   cmd_status "$@" ;;
    detect)   cmd_detect "$@" ;;
    apply)    cmd_apply "$@" ;;
    discover) cmd_discover "$@" ;;
    revert)   cmd_revert "$@" ;;
    ""|-h|--help|help) usage ;;
    *) usage; echo; die "Unknown command: $cmd" ;;
  esac
}

main "$@"
