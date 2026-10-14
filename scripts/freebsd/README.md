# FreeBSD script

[`i915-freebsd.sh`](i915-freebsd.sh) enables the Intel KMS driver on FreeBSD and
(optionally) forces a mode.

```sh
sudo sh i915-freebsd.sh                 # enable i915kms + vt, show state
sudo sh i915-freebsd.sh HDMI-1 1366x768 # also try to force a mode under X
```

It edits `/boot/loader.conf` (with a timestamped backup):

```
i915kms_load="YES"
kern.vty=vt
```

and loads the module immediately with `kldload i915kms`.

See [`docs/07-other-os.md`](../../docs/07-other-os.md) for the full FreeBSD path,
including Xorg `PreferredMode` pinning.
