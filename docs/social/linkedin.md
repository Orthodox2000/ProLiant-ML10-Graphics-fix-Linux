# Social media kit — LinkedIn (AI / “make your own driver” angle)

Everything you need to announce the project. Copy, paste, upload, done.
Nothing else required.

- **Landscape image (post / link preview):** [`assets/linkedin/linkedin-1200x627.png`](../../assets/linkedin/linkedin-1200x627.png) — 1200×627
- **Square image (bigger feed visual):** [`assets/linkedin/linkedin-1080x1080.png`](../../assets/linkedin/linkedin-1080x1080.png) — 1080×1080
- **Repo link:** https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux

Regenerate the images any time with `make social`
(or `bash scripts/doc/make-social.sh`).

**The angle in one line:** *with AI you can now write your own driver-level fix,
so old hardware keeps working on a modern OS — we did exactly that.*

---

## 1. Post structure (the anatomy)

Use this skeleton for any platform. Each block has a job.

| # | Block | Job | Length |
|---|---|---|---|
| 1 | **Hook** | Stop the scroll. The AI/driver idea. | 1 line |
| 2 | **Reframe** | Why this matters — “old hardware” vs disappearing vendor support. | 2–3 lines |
| 3 | **Problem (by behaviour, not specs)** | Describe the *symptom*, never “CPU X is broken”. | 3–4 lines |
| 4 | **The insight** | “This is a *driver* problem” — the aha that justifies building our own. | 3–4 lines |
| 5 | **What we built** | Our own driver-level toolkit. Bullets + the key snippet. | 6–8 lines |
| 6 | **Result** | One punchy line. Before → after. | 1 line |
| 7 | **The bigger point** | Right-to-repair / e-waste / “we can now write the glue ourselves”. | 2–3 lines |
| 8 | **CTA** | Repo link. | 1 line |
| 9 | **Hashtags** | 8–12, mixed reach. | 1 line |

**Formatting rules**
- Lead with a bolded hook line; LinkedIn collapses after ~3 lines — make them count.
- Short paragraphs (1–3 lines), single blank line between them.
- **Bold** the section leads; 🔧🪟🐧📄 emoji as section markers (not decoration spam).
- Put the link **once**, at the end. Put extra links in the first comment.
- No CPU/GPU model as the identifier. Name the *behaviour* (“goes dark after POST”).

---

## 2. Post text (primary — the AI / DIY-driver angle)

> 🧠 **With AI, you can now write your own drivers — and keep old hardware alive.**
>
> For years, “old hardware on a new system” meant hunting for a vendor driver that
> no longer exists, or was never written for your OS. When support ends, you’re
> stuck — unless you write the fix yourself.
>
> So we did.
>
> **The problem (by behaviour, not specs):**
> A perfectly good small tower server. Add a monitor through a passive
> **DP → DVI → HDMI** adapter chain, and it goes dark right after POST. The OS
> loads, the machine is alive — there’s just no signal.
>
> The usual advice is `nomodeset`. It “works”… by giving up on the GPU entirely and
> pinning you to a slow 1024×768 firmware framebuffer. That isn’t a fix, it’s
> surrender.
>
> **The insight — this is a *driver* problem.**
> The passive adapter **hides the monitor’s EDID**, so the graphics driver’s bus
> read fails, it falls back to slow bit-banging, and the output is **never
> enabled**. Second trap: two different connector names can be the *same* physical
> port — try to force both and you get nothing.
>
> No vendor is going to ship a driver for a discontinued box on a modern kernel.
> So we wrote the driver-level fix ourselves.
>
> **What we built — our own driver toolkit:**
> 🔧 **Linux** — a portable toolkit for **GRUB *and* systemd-boot**:
>   `status`, `detect`, `apply`, `discover`, `revert`. Non-destructive, timestamped
>   backups, and a guaranteed recovery entry so you can never get stuck on a black
>   screen. It does what a driver would — names the right connector, sets the exact
>   mode, and switches off the power features that keep the output asleep:
>
> ```
> video=<connector>:1366x768@60e i915.enable_dc=0 i915.enable_psr=0 i915.enable_fbc=0
> ```
>
> 🪟 **Windows / Windows Server** — our own tooling, including a small
>   **`DisplayFix.exe` we wrote and compiled** (source included; unsigned — audit it).
> 🐧 **FreeBSD / TrueNAS / pfSense / Proxmox** — helpers for the same fix.
> 📄 A **52-page write-up**, real screenshots, and full troubleshooting.
>
> **The result:**
> The machine that showed *nothing* now runs at its **native 1366×768 @ 60 Hz,
> hardware accelerated.** Old hardware, modern OS, working.
>
> **The real point:**
> AI didn’t magically support the hardware — it let *us* do the driver-level work
> that used to require a vendor: read the driver/kernel behaviour, find the exact
> parameters, and ship a tool anyone can run. That’s the unlock. **Old hardware
> gets a second life because we can now write the glue ourselves.** Less e-waste,
> less “buy new”, more “make it work”.
>
> 🔗 Full write-up + toolkit:
> https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux
>
> #AI #OpenSource #Linux #WindowsServer #FreeBSD #Drivers #Hardware #SysAdmin #Homelab #RightToRepair #Sustainability #DisplayPort

---

## 3. Short version (mobile / higher completion)

> 🧠 **With AI, you can now make your own drivers — so old hardware keeps working
> on a modern OS.**
>
> We had a perfectly good tower server that went **dark right after POST** through a
> passive **DP → DVI → HDMI** chain. The adapter **hides the monitor’s EDID**, so the
> graphics driver never enables the output. `nomodeset` only *pretends* to fix it
> (1024×768, no acceleration).
>
> No vendor is shipping a driver for a discontinued box — so we wrote the fix
> ourselves: a tiny toolkit that tells the driver the right connector, the exact
> mode, and to stop sleeping.
>
> Result: **1366×768 @ 60 Hz, accelerated.** Old hardware, second life.
>
> Linux (GRUB + systemd-boot), Windows Server, and FreeBSD, with a safe recovery
> entry so you can never get stuck. Full write-up + a 52-page PDF:
>
> 🔗 https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux
>
> #AI #OpenSource #Linux #Drivers #Hardware #SysAdmin #RightToRepair

---

## 4. Carousel format (optional — 6 slides)

If you’d rather post a document/carousel, each slide maps to a block above:

| Slide | Headline | Body |
|---|---|---|
| 1 | **We made our own driver.** | AI-assisted. No vendor driver needed. |
| 2 | **The problem** | A good server goes dark right after POST over DP → DVI → HDMI. |
| 3 | **Why “nomodeset” isn’t a fix** | It abandons the GPU: 1024×768, no acceleration. Surrender. |
| 4 | **The real cause** | The adapter hides the monitor’s EDID → the output is never enabled. |
| 5 | **What we built** | Our own toolkit: Linux (GRUB/systemd-boot), Windows `.exe`, FreeBSD. |
| 6 | **The result + link** | 1366×768 @ 60 Hz, accelerated. Repo link + QR. |

---

## 5. First comment (post it yourself, right after publishing)

> For anyone with different gear: the method is the same — find the real connector
> name (`ls /sys/class/drm`), set `video=<connector>:<mode>@60e`, and remember two
> port names can be the *same* physical port. If nothing shows at all, boot with
> `nomodeset` and run `scripts/linux/i915-display-fix.sh discover` — it prints the
> exact line to add. `apply` always installs a recovery entry, so you can’t get stuck.
>
> (Windows Server folks: `docs/06-windows-server.md`. Cable/adapter questions:
> `docs/08-hardware-cables-adapters.md`.)

---

## 6. Alt text (paste into the image’s “alt text” field)

> Dark title card reading “We made our own driver.” with the subtitle “Old hardware,
> modern system — fixed at the driver level”, a signal chain DP++ → DVI → HDMI
> labelled “output never enabled” then “our fix”, chips for Linux, Windows Server,
> FreeBSD and our own DisplayFix.exe, and a footer “1366×768 @ 60 Hz · our own
> toolkit, hardware accelerated”.

---

## 7. What to upload and where

| Step | Where (LinkedIn) | What |
|---|---|---|
| 1 | Home → **Start a post** | Paste **§2 Post text** |
| 2 | Same composer → **🖼️ image icon** | Upload **`linkedin-1200x627.png`** (or the square) |
| 3 | In the text, at the end | Paste the repo URL as **plain text** |
| 4 | Right after publishing → **comment on your own post** | Paste **§5 First comment** |
| 5 | Profile → **Add profile section → Featured → Add a link** | Repo URL, title “Making our own driver for old hardware” |
| 6 | Optional: **Write article** | Use **`docs/dist/ProLiant-ML10-Graphics-fix.pdf`** as the source |

> ⚠️ **Pick one:** if you upload an image **and** paste the URL, LinkedIn shows your
> image. If you want the automatic **link card** (which uses the repo’s social
> preview), paste only the URL and upload nothing. Don’t do both.

---

## 8. Re-using on other platforms

| Platform | Image | Notes |
|---|---|---|
| **X / Twitter** | `linkedin-1200x627.png` | Fits the card; link at the end. |
| **Mastodon** | `linkedin-1200x627.png` | Same geometry. |
| **Reddit** (`r/linux`, `r/sysadmin`, `r/homelab`, `r/HomeServer`, `r/linuxhardware`) | `linkedin-1080x1080.png` | Short text as **title**, long text as **body**, link in the body (not a link post). |
| **Hacker News** | none | Text only; drop the emoji and hashtags. |
| **ServeTheHome / forums** | `linkedin-1200x627.png` | Paste the long text. |

### Reddit title suggestions
- `We wrote our own driver-level fix so a discontinued server runs its monitor on a modern OS`
- `AI-assisted driver work: fixing a black-screen DP→DVI→HDMI output with our own toolkit`

---

## 9. Posting rhythm

1. **Day 0** — primary post + landscape image.
2. **Day 0 (+1h)** — first comment.
3. **Day 2–3** — a short follow-up with the **square** image and one concrete
   lesson (e.g. “two port names, one physical port”) for a second wave.
4. Keep replies technical and specific; link the exact doc file when relevant.
