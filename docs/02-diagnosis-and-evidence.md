# 2. Diagnosis & evidence

This is the actual investigation that produced the fix, in order, with the real
commands and their outputs. You can reproduce every step on your own ML10.

## 2.1 Identify the GPU and driver

```console
$ lspci -nnk | grep -A3 -iE 'VGA|Display'
00:02.0 VGA compatible controller [0300]: Intel Corporation HD Graphics P530 [8086:191d] (rev 06)
        DeviceName:  Onboard IGD
        Subsystem: Intel Corporation HD Graphics P530 [8086:2212]
        Kernel driver in use: i915
```

So the hardware *is* supported by `i915`. (`00:02.0` is the standard location of
the Intel iGPU.)

## 2.2 Confirm what is *actually* driving the display

```console
$ cat /proc/cmdline
... ro quiet splash nomodeset
$ grep -w i915 /proc/modules || echo "i915 NOT loaded"
i915 NOT loaded
$ lsmod | grep -E 'i915|simpledrm'
simpledrm    ...
```

With `nomodeset`, only the **firmware framebuffer** (`simpledrm`) is active. That
is why the resolution is fixed and unchangeable: nothing is programming the CRTC.

## 2.3 Prove that `nomodeset` is the blocker

```console
$ sudo modprobe i915
modprobe: ERROR: could not insert 'i915': No such device
```

`i915` refuses to bind **while `nomodeset` is active** — it is not a missing
driver, it is a kernel policy flag (`video_firmware_drivers_only()`), and it is
**boot-time only**. No amount of `rmmod`/`modprobe` will fix it; you must change
the kernel command line and reboot.

## 2.4 Look at the connector the firmware left enabled

Booting once **without** `nomodeset` and with verbose DRM logging
(`drm.debug=0x1e`) makes `i915` speak. Two things jump out.

### (a) The port really is dual-mode

```
i915 ... [drm:intel_bios_init] Port B VBT info: CRT:0 DVI:1 HDMI:1 DP:1 DP++:1
i915 ... [drm:intel_bios_init] Port C VBT info: CRT:0 DVI:1 HDMI:1 DP:1 DP++:1
i915 ... [drm:intel_bios_init] Port D VBT info: CRT:0 DVI:1 HDMI:1 DP:1 DP++:1
```

`DP++:1` on ports B/C/D means the GPU **can** emit TMDS (DVI/HDMI) through a
passive adapter. The adapter is not the (only) problem.

### (b) EDID does not come through cleanly

```
i915 ... [drm:intel_hdmi_set_edid] HDMI GMBUS EDID read failed, retry using GPIO bit-banging
i915 ... [drm:intel_hdmi_set_edid] HDMI GMBUS EDID read failed, retry using GPIO bit-banging
...
```

Hundreds of these. The GMBUS (hardware DDC) read fails; the kernel falls back to
**bit-banging** the DDC lines, which is slow and racy at boot. If it loses the
race, the connector is treated as “disconnected” and the output stays dark.

### (c) A dual-mode port has TWO names

```
i915 ... [drm:intel_dp_init_connector]   Adding DP connector on [ENCODER:109:DDI B/PHY B]
i915 ... [drm:intel_hdmi_init_connector] Adding HDMI connector on [ENCODER:109:DDI B/PHY B]
...
i915 ... [CONNECTOR:120:HDMI-A-1] hw state readout: enabled
```

`DP-1` and `HDMI-A-1` are the **same physical port** (DDI B). The BIOS left
`HDMI-A-1` enabled, i.e. that is the connector your cable is on.

## 2.5 The first, wrong “fix” — and why it failed

Forcing **all** candidate connectors:

```
video=DP-1:1366x768@60e video=DP-2:1366x768@60e \
video=HDMI-A-1:1366x768@60e video=HDMI-A-2:1366x768@60e
```

produced **“signal, but a black screen with a flickering cursor”**. The kernel
explains why:

```
i915 ... [drm:handle_conflicting_encoders] [ENCODER:109:DDI B/PHY B] in use on
        [CRTC:58:pipe A], disabling [CONNECTOR:120:HDMI-A-1]
i915 ... [drm:update_connector_routing] Disabling [CONNECTOR:110:DP-1]
```

`DP-1` grabbed the DDI B encoder, so the driver **kept disabling the real monitor**
(`HDMI-A-1`). Xorg then saw four outputs (two of them phantom) and set them all to
640×480 — hence black screen, occasional cursor.

## 2.6 The correct fix

Force **only the connector that matches the cable**:

```
video=HDMI-A-1:1366x768@60e
```

Result on the reference machine:

```console
$ cat /proc/cmdline
... quiet splash i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0 \
    i915.enable_dp_mst=0 i915.disable_power_well=0 video=HDMI-A-1:1366x768@60e

$ head -1 /sys/class/drm/card1-HDMI-A-1/modes
1366x768
$ xrandr | grep connected
HDMI-1 connected primary 1366x768+0+0 ...
$ glxinfo | grep 'OpenGL renderer'
OpenGL renderer string: Mesa Intel(R) HD Graphics P530 (SKL GT2)
```

## 2.7 Evidence files in this repo

| File | Contents |
|---|---|
| [`examples/lspci-gpu.txt`](../examples/lspci-gpu.txt) | GPU + driver |
| [`examples/cpu.txt`](../examples/cpu.txt) | CPU flags |
| [`examples/system.txt`](../examples/system.txt) | Board + BIOS |
| [`examples/working-cmdline.txt`](../examples/working-cmdline.txt) | The working kernel line |
| [`examples/drm-connectors-working.txt`](../examples/drm-connectors-working.txt) | Connector states |
| [`examples/xrandr-working.txt`](../examples/xrandr-working.txt) | X outputs + modes |
| [`examples/i915-vbt-ports.txt`](../examples/i915-vbt-ports.txt) | DP++ proof |
| [`examples/i915-edid-noise.txt`](../examples/i915-edid-noise.txt) | EDID/GMBUS failure |
| [`examples/i915-encoder-conflict.txt`](../examples/i915-encoder-conflict.txt) | The dual-name trap |
| [`examples/modeline-1366x768.txt`](../examples/modeline-1366x768.txt) | Mode timings |
| [`examples/modinfo-i915.txt`](../examples/modinfo-i915.txt) | Module info |

To gather the same data on your machine, run
[`scripts/linux/i915-collect.sh`](../scripts/linux/i915-collect.sh).
