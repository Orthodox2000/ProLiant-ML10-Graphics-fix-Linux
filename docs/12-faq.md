# 12. FAQ

**Q: Is my ML10 Gen9’s iGPU actually supported?**
Yes. The HD Graphics P530 (`8086:191d`) is fully supported by Linux `i915` and by
the Windows Intel graphics driver. HP does not ship a Windows Server driver for
it, which is why it “looks” unsupported.

**Q: Why does `nomodeset` “work” then?**
Because it does not use the GPU at all — it uses the BIOS’s simple framebuffer
(`simpledrm`). That is why you are stuck at 1024×768 with no acceleration.

**Q: Can I fix this without rebooting?**
No. `nomodeset` is read once at boot. Live `modprobe i915` fails while it is set.

**Q: Do I really need the `i915.enable_*` flags?**
Usually only `video=<conn>:<WxH>@<Hz>e` (and removing `nomodeset`) is required.
The flags are conservative stability tweaks for Skylake; keep them if you saw
flicker, drop them if you prefer default power behaviour and it still works.

**Q: Why do I have to name `HDMI-A-1` when the port is a DisplayPort?**
Because a DP++ port is dual-mode. In HDMI/DVI mode the kernel exposes it under
the `HDMI-A-x` name. `DP-1` and `HDMI-A-1` are the same physical port.

**Q: I forced both and got a black screen with a cursor. Why?**
Two connectors on one port fight over the shared encoder
(`handle_conflicting_encoders`), so the driver keeps disabling your monitor. Force
only one.

**Q: Can I use my monitor’s full 1920×1080?**
Yes, if the monitor and adapter support it. Put the native mode in the token:
`video=HDMI-A-1:1920x1080@60e`. Verify the mode exists:
`cat /sys/class/drm/card*-HDMI-A-1/modes`.

**Q: Will this survive kernel updates?**
Yes. `/etc/default/grub` is static, and `update-grub`/`grub2-mkconfig` regenerates
from it for every installed kernel. The optional custom recovery entry hardcodes
the kernel of the day; re-run `apply` after a major upgrade, or rely on your
distro’s built-in recovery entry.

**Q: What about Secure Boot?**
The fix does not touch boot signing; it only changes the kernel command line. It
works with Secure Boot enabled. The Windows `.exe` approach is unaffected.

**Q: Does this help on Windows?**
Not directly. On Windows install the Intel driver and use an **active** adapter;
the `video=` concept does not exist there. See
[docs/06-windows-server.md](06-windows-server.md).

**Q: Is a passive adapter really the problem?**
It is the *root* of the EDID failure. Passive DP→HDMI/DVI plugs do not regenerate
DDC. An active adapter removes the need for the software workaround.

**Q: I only see 640×480. Is that a different bug?**
No. It is the same: without EDID the driver/OS falls back to a safe low mode. Force
the mode, then consider an active adapter.

**Q: Can I disable `nomodeset` but keep text-only boot?**
Yes — use `nomodeset` only for the recovery entry; the normal entry should not
have it. That is exactly what this repo sets up.

**Q: How do I go back?**
`sudo ./scripts/linux/i915-display-fix.sh revert`, or restore the `.bak` of
`/etc/default/grub` and `update-grub`. A recovery GRUB entry is always left in
place.

**Q: Why did my GRUB menu get a duplicate/garbled entry after editing?**
Because a `*.bak` file was left inside `/etc/grub.d/`, which GRUB executes. Keep
backups elsewhere (the toolkit uses `/var/backups/i915-display-fix/`).

**Q: Will this work on a monitor with DisplayPort directly (no adapter)?**
Yes, and it is the best case. You may not even need the `video=` force; plain
`nomodeset`-removal is likely enough.

**Q: Is there a risk of bricking the display permanently?**
No. All changes are file-based and reversible, and a `nomodeset` recovery entry is
always available. Even in the worst case you reach a console with a live USB.
