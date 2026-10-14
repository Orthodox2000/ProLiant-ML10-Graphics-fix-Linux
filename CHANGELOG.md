# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-10-14

Initial release.

### Added
- Complete root-cause analysis for the ML10 Gen9 (Intel HD Graphics P530)
  display failure over a DP→DVI→HDMI chain.
  - `nomodeset` behaviour and `video_firmware_drivers_only()`.
  - EDID/GMBUS failure and the GPIO bit-bang fallback.
  - The dual-name DP++ port trap (`DP-1` vs `HDMI-A-1` on the same DDI).
  - Skylake power-feature stability flags.
- **Linux toolkit** `scripts/linux/i915-display-fix.sh` with `status`, `detect`,
  `apply`, `discover`, `revert`; supports GRUB (Debian/Ubuntu/Mint, Fedora/RHEL,
  Arch, openSUSE) and systemd-boot.
- `scripts/linux/i915-collect.sh` diagnostic collector.
- `scripts/linux/finalize-i915.sh` one-shot applier.
- **Windows / Windows Server** tooling:
  - `Get-GraphicsInfo.ps1`, `Set-DisplayResolution.ps1`,
    `Install-IntelGraphicsDriver.ps1`, `Fix-Display.bat`.
  - `DisplayFix.exe` (native, ~44 KB, built from `src/DisplayFix.c`) plus source.
- **FreeBSD** helper `scripts/freebsd/i915-freebsd.sh`.
- Full documentation set (`docs/01`–`docs/12`) covering problem, diagnosis,
  root cause, Linux solution, per-distro guide, Windows Server, other OSes,
  hardware/cables/adapters, troubleshooting, verification, reference and FAQ.
- Real diagnostic captures in `examples/`.
- `Makefile` (build the Windows `.exe`, lint), `install.sh`, CI workflow.

### Verified on
- HPE ProLiant ML10 Gen9, BIOS 1.010, Xeon E3-1225 v5, HD Graphics P530.
- Linux Mint 22.3, kernels 7.0.0-38-generic and 6.14.0-37-generic.
- Monitor 1366×768 via DP→DVI→HDMI. Result: 1366×768 @ 60 Hz, i915 + Mesa.
