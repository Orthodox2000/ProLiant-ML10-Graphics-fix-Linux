# 5. Distribution & bootloader guide

The toolkit edits the **bootloader**, so one script covers every GRUB-based and
systemd-boot-based distribution. `status` and `detect` are read-only and safe
everywhere; `apply`/`revert`/`discover` need root.

| OS / family | Versions covered | Bootloader | Regeneration command |
|---|---|---|---|
| Ubuntu / Linux Mint / Pop!_OS / elementary / Zorin | 20.04, 22.04, 24.04, LM 20–22 | GRUB | `update-grub` |
| Debian | 10, 11, 12, 13 | GRUB | `update-grub` |
| Fedora / RHEL / CentOS Stream / Rocky / Alma | 8, 9, 10 | GRUB2 | `grub2-mkconfig -o /boot/grub2/grub.cfg` |
| Arch / Manjaro / EndeavourOS | rolling | GRUB **or** systemd-boot | `grub-mkconfig -o /boot/grub/grub.cfg` |
| openSUSE Leap / Tumbleweed / SLES | 15.x | GRUB2 | `grub2-mkconfig -o /boot/grub2/grub.cfg` |
| NixOS | any | GRUB/systemd-boot | declarative (`configuration.nix`) |
| Void / Gentoo / Alpine | any | various | manual |

The script auto-detects the distribution (`/etc/os-release`), the correct
regeneration tool, and the GRUB config path. **Kernel version does not matter** —
only `uname -r` is used to locate the image for the optional recovery entry.

---

## 5.1 Ubuntu / Linux Mint / Debian / Pop!_OS

```bash
./i915-display-fix.sh detect
sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
sudo reboot
```

Equivalent manual edit of `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e"
```
then `sudo update-grub`.

## 5.2 Fedora / RHEL / Rocky / AlmaLinux / CentOS Stream

```bash
sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
# or, the distro-native way:
sudo grubby --update-kernel=ALL --remove-args=nomodeset \
  --args='i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e'
```

- **UEFI and BIOS both work.** The GRUB config on UEFI Fedora is still
  `/boot/grub2/grub.cfg` (the `EFI/fedora/grub.cfg` file is a stub that loads it).
- `grubby` is present on RHEL-family systems and is the safest option; it edits
  all kernel entries at once.
- After a **kernel update**, `grubby --update-kernel=ALL` persists, but a plain
  `grub2-mkconfig` edit of `/etc/default/grub` also persists. Both are fine.

## 5.3 Arch / Manjaro / EndeavourOS

Detect which bootloader you use:

```bash
[ -d /boot/loader/entries ] && echo systemd-boot || echo grub
```

GRUB:
```bash
sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
```

systemd-boot (the toolkit edits `/boot/loader/entries/*.conf`):
```bash
sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
```
Manual equivalent — edit the `options` line of your entry, e.g.
`/boot/loader/entries/arch.conf`:

```
options root=UUID=... rw quiet i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e
```

Add a recovery entry by copying the file and appending `nomodeset`:
```bash
sudo cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-recovery.conf
sudo sed -i 's/$/ nomodeset/' /boot/loader/entries/arch-recovery.conf
```

## 5.4 openSUSE Leap / Tumbleweed / SLES

```bash
sudo ./i915-display-fix.sh apply --connector HDMI-A-1 --mode 1366x768
# manual:
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="... video=HDMI-A-1:1366x768@60e"/' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```
YaST → *Boot Loader* → *Kernel Parameters* also works if you prefer a GUI.

## 5.5 NixOS (declarative — the script cannot edit it safely)

In `/etc/nixos/configuration.nix`:

```nix
{
  boot.kernelParams = [
    "i915.enable_dc=0"
    "i915.enable_psr=0"
    "i915.enable_fbc=0"
    "i915.enable_dp_mst=0"
    "i915.disable_power_well=0"
    "video=HDMI-A-1:1366x768@60e"
  ];
  # keep several generations so you can roll back at the boot menu
  boot.loader.grub.configurationLimit = 10;
  # never put "nomodeset" here:
  # boot.kernelParams = [ "nomodeset" ];   # <-- do NOT do this
}
```
Then `sudo nixos-rebuild switch`. Roll back with `nixos-rebuild switch --rollback`
or by picking an older generation in the boot menu.

## 5.6 Void / Gentoo / Alpine and other bootloaders

`apply` prints the parameters to use and leaves the bootloader alone when it does
not recognise it. Add these to your kernel command line:

```
i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e
```

- **Void:** `/etc/default/grub` + `sudo update-grub` (same as Debian), or edit
  `/boot/loader/entries/` for systemd-boot.
- **Gentoo:** often a hand-written `/boot/grub/grub.cfg`; append the parameters to
  the `linux` line.
- **Alpine:** `/etc/update-extlinux.conf` (extlinux) or the GRUB config; append to
  `default_kernel_opts` / the kernel line.
- **rEFInd:** edit `/boot/refind_linux.conf`.

---

## Persisting the resolution in X

The `video=` force sets the mode at boot, which is usually enough for GDM/SDDM/LightDM.
If your desktop still starts at a lower mode, pin it per-user or system-wide.

**Per-user (all desktops):** add a desktop autostart script:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/i915-resolution.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Set 1366x768
Exec=sh -c "sleep 3; xrandr --output HDMI-1 --mode 1366x768 || xrandr --output HDMI-1 --auto"
X-GNOME-Autostart-enabled=true
EOF
```

**System-wide (Xorg, all users):** `/etc/X11/xorg.conf.d/20-i915-mode.conf`:

```
Section "Monitor"
    Identifier "HDMI-1"
    Option "PreferredMode" "1366x768"
EndSection
```

(Requires the `modesetting` driver, which is the default for Intel.)

**Wayland (GNOME/KDE):** the kernel `video=` mode is honoured at boot; change the
mode from the desktop’s Display settings.
