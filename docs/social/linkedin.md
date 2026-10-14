# Social media kit — LinkedIn (and re-usable for X / Mastodon / Reddit)

Everything you need to announce the project. Copy/paste the text, upload the
image, paste the repo link. Nothing else required.

- **Landscape image (link preview / feed):** [`assets/linkedin/linkedin-1200x627.png`](../../assets/linkedin/linkedin-1200x627.png) — 1200×627
- **Square image (feed post):** [`assets/linkedin/linkedin-1080x1080.png`](../../assets/linkedin/linkedin-1080x1080.png) — 1080×1080
- **Repo link:** https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux

Regenerate the images any time with `make social` (or
`bash scripts/doc/make-social.sh`).

---

## TL;DR — what to upload and where

| Step | Where | What |
|---|---|---|
| 1 | LinkedIn → **Start a post** ("Create post") | Paste the **Post text** below |
| 2 | Same composer → **Add media / image icon** | Upload **`linkedin-1200x627.png`** (or the square for a bigger visual) |
| 3 | In the post text, the repo URL | Leave it as plain text so LinkedIn builds a preview card (it uses the repo's **social preview** image automatically) |
| 4 | After posting → **your first comment** | Paste the **First comment** text (keeps the post clean, boosts reach) |
| 5 | (Optional) Your profile → **Add profile section → Featured → Add a link** | Repo link, title "HP ProLiant ML10 Gen9 display fix" |
| 6 | (Optional) **Articles** → New article | Use **`docs/dist/ProLiant-ML10-Graphics-fix.pdf`** as the source |

> ⚠️ **Pick one image, not both.** If you paste the repo URL *and* upload an
> image, LinkedIn shows your uploaded image (good). If you want the automatic
> **link card** instead, just paste the URL and upload nothing.

---

## Post text (primary — "engineer, problem-solving" tone)

> A brand new HPE ProLiant ML10 Gen9, and a monitor that just… stays black.
> Here's the whole root cause — and the fix I wish existed last week. 🧵
>
> **The setup:** ML10 Gen9, Intel HD Graphics P530 (Skylake), a 1366×768 monitor
> on the motherboard's DisplayPort through a passive **DP → DVI → HDMI** chain.
>
> **The symptom:** picture through BIOS/POST, then nothing. Adding `nomodeset`
> "works" — but it just abandons the GPU and pins you to a 1024×768 firmware
> framebuffer with zero acceleration. Not a fix.
>
> **The root cause:** the passive adapter hides the monitor's **EDID**. The i915
> driver's GMBUS read fails, falls back to slow GPIO bit-banging, and never
> enables the output. There's a nasty second trap too: `DP-1` and `HDMI-A-1` are
> the **same physical DP++ port** — try to force both and you get nothing.
>
> **The fix:** drop `nomodeset`, hand the kernel the exact connector + mode, and
> switch off a few Skylake power features:
>
> ```
> video=HDMI-A-1:1366x768@60e i915.enable_dc=0 \
> i915.enable_psr=0 i915.enable_fbc=0 i915.enable_dp_mst=0
> ```
>
> **The result:** 1366×768 @ 60 Hz, i915 loaded, hardware accelerated. The screen
> it was supposed to have all along.
>
> I turned the whole investigation into a documented, reusable project:
>
> 🔧 Portable **Linux toolkit** (GRUB **and** systemd-boot): `status`, `detect`,
>   `apply`, `discover`, `revert` — non-destructive, timestamped backups, and a
>   guaranteed `nomodeset` **recovery entry** so you can never end up with a
>   black screen you can't undo.
> 🪟 **Windows + Windows Server** guide and tooling, including a tiny
>   **DisplayFix.exe** (source included, unsigned — audit and rebuild it if you
>   prefer).
> 🐧 **FreeBSD** helper, plus hardware / cable / adapter guidance (active vs
>   passive DP adapters, KVMs, alternate outputs).
> 📄 A **52-page PDF**, real terminal screenshots, per-distro notes, and full
>   troubleshooting.
>
> If you've fought a "DP works on paper, black on screen" server, this one's for
> you. Feedback, other boards/distros, and PRs welcome.
>
> 🔗 https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux
>
> #Linux #WindowsServer #Hardware #SysAdmin #OpenSource #Intel #HPE #ProLiant #i915 #Troubleshooting #DisplayPort

---

## Post text (short — better for mobile / higher completion rate)

> Spent longer than I'd like on a **black screen** from a brand-new HPE ProLiant
> ML10 Gen9 over DisplayPort→HDMI. The cause wasn't the monitor or the cable — a
> **passive DP→DVI→HDMI adapter hides the monitor's EDID**, so the Intel i915
> driver never enables the output. `nomodeset` only *pretends* to fix it (1024×768,
> no acceleration).
>
> The real fix, on the kernel command line:
>
> ```
> video=HDMI-A-1:1366x768@60e i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0
> ```
>
> Result: **1366×768 @ 60 Hz, accelerated.**
>
> I wrote the whole thing up — Linux toolkit (GRUB + systemd-boot, with a safe
> recovery entry), Windows Server tools, FreeBSD, cable/adapter guidance, and a
> 52-page PDF.
>
> 🔗 https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux
>
> #Linux #WindowsServer #SysAdmin #Hardware #OpenSource #i915 #ProLiant

---

## First comment (post this yourself, right after publishing)

> For anyone who lands here with a different box: the logic is the same — find
> the real connector name (`ls /sys/class/drm`), set `video=<connector>:<mode>@60e`,
> and remember that `DP-1` and `HDMI-A-1` can be the *same* physical port. If
> nothing shows up at all, boot with `nomodeset` and run
> `scripts/linux/i915-display-fix.sh discover` — it prints the exact line to add.
> The `apply` command always installs a recovery entry, so you can't get stuck.

---

## Alt text (accessibility — paste into the image's "alt text" field)

> Dark title card reading "HP ProLiant ML10 Gen9 — Black screen on DisplayPort→HDMI?" with a signal chain DP++ → DVI → HDMI, the note "EDID dropped / fixed", chips for Linux, Windows Server, FreeBSD and DisplayFix.exe, and the line "1366×768 @ 60 Hz · i915 + hardware acceleration".

---

## Re-using on other platforms

| Platform | Image | Notes |
|---|---|---|
| **X / Twitter** | `linkedin-1200x627.png` | Fits the 16:9-ish card; add the repo link. |
| **Mastodon** | `linkedin-1200x627.png` | Same card geometry. |
| **Reddit** (`r/linux`, `r/sysadmin`, `r/homelab`, `r/HomeServer`) | `linkedin-1080x1080.png` | Use the **short** text as the title, the long text as the body; link in the body to avoid being flagged as a link post. |
| **Hacker News** | none | Text only; use the short text minus hashtags. |
| **Server The Home / forums** | `linkedin-1200x627.png` | Paste the long text; BBCode image link if needed. |

### Reddit title suggestions

- `Fixed the black-screen/DP→HDMI issue on an HP ProLiant ML10 Gen9 (Intel P530 / i915) — full write-up + toolkit`
- `PSA: a passive DP→DVI→HDMI adapter can hide your monitor's EDID and leave a Skylake iGPU output dark`

---

## Suggested posting rhythm

1. **Day 0** — the primary post + landscape image.
2. **Day 0 (+1h)** — first comment (above).
3. **Day 2–3** — a short "update" post with the **square** image and one concrete
   lesson (e.g. the `DP-1` / `HDMI-A-1` same-port trap) to catch a second wave.
4. Keep replies technical and specific; link to the exact doc file
   (`docs/09-troubleshooting.md`, `docs/06-windows-server.md`) when relevant.
