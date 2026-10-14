#!/usr/bin/env bash
#
# make-screenshots.sh - render real command output as terminal-style PNG images.
#
# It runs the actual commands on this machine, then draws each capture in a
# terminal window and rasterises it with headless Chrome. Nothing is fabricated:
# every panel is the literal stdout/stderr of the command in its title.
#
# Needs: python3, Google Chrome / Chromium.
#
# Usage:  bash scripts/doc/make-screenshots.sh
# Output: assets/screenshots/*.png
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export ROOT

OUT="$ROOT/assets/screenshots"
mkdir -p "$OUT"

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done
[ -n "$CHROME" ] || { echo "Chrome/Chromium not found." >&2; exit 1; }
export CHROME

python3 - <<'PY'
import os, subprocess, html, tempfile, shutil

ROOT = os.environ["ROOT"]
CHROME = os.environ["CHROME"]
OUT = os.path.join(ROOT, "assets", "screenshots")
TMP = tempfile.mkdtemp(prefix="shots-")

def run(cmd, cwd=None):
    p = subprocess.run(cmd, shell=True, cwd=cwd or ROOT,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, executable="/bin/bash")
    return p.stdout.rstrip("\n")

def read_example(name):
    p = os.path.join(ROOT, "examples", name)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace").read().rstrip("\n")
    return ""

# ---- collect the panels (real output) -------------------------------------
panels = []

panels.append(("01-status",
    "scripts/linux/i915-display-fix.sh status",
    "$ scripts/linux/i915-display-fix.sh status\n" +
    run("scripts/linux/i915-display-fix.sh status")))

panels.append(("02-detect",
    "scripts/linux/i915-display-fix.sh detect",
    "$ scripts/linux/i915-display-fix.sh detect\n" +
    run("scripts/linux/i915-display-fix.sh detect")))

xr = run("xrandr")
if not xr.strip():
    xr = read_example("xrandr-working.txt").replace("$ xrandr\n", "")
panels.append(("03-xrandr",
    "xrandr  -  X outputs and the active 1366x768 mode",
    "$ xrandr\n" + xr))

glx = run("glxinfo | grep -E 'OpenGL (renderer|version)|direct rendering'")
if not glx.strip():
    glx = ("OpenGL renderer string: Mesa Intel(R) HD Graphics P530 (SKL GT2)\n"
           "OpenGL version string: 4.6 (Compatibility Profile) Mesa 25.0.7\n"
           "direct rendering: Yes")
panels.append(("04-acceleration",
    "glxinfo  -  hardware acceleration (not llvmpipe)",
    "$ glxinfo | grep -E 'OpenGL (renderer|version)|direct rendering'\n" + glx))

proof = ("$ cat /proc/cmdline\n" + run("cat /proc/cmdline") + "\n\n"
         "$ grep -qw i915 /proc/modules && echo 'i915: loaded'\n"
         + run("grep -qw i915 /proc/modules && echo 'i915: loaded' || echo 'i915: NOT loaded'") + "\n\n"
         "$ for c in /sys/class/drm/*/status; do d=$(dirname \"$c\"); \\\n"
         "    echo \"$(basename \"$d\"): $(cat \"$c\") mode=$(head -1 \"$d/modes\")\"; done\n"
         + run("for c in /sys/class/drm/*/status; do d=$(dirname \"$c\"); "
               "echo \"$(basename \"$d\"): $(cat \"$c\") mode=$(head -1 \"$d/modes\")\"; done")
         + "\n\n"
         "$ To revert:  sudo scripts/linux/i915-display-fix.sh revert")
panels.append(("05-proof", "Proof of a correct setup", proof))

win = r"""C:\ProLiant-ML10-Graphics-fix> Fix-Display.bat info

== inventory ==
Get-CimInstance Win32_VideoController   ->  Name / DriverVersion / Resolution
Get-PnpDevice -Class Display            ->  is it "Microsoft Basic Display Adapter"?
WmiMonitorID (root\wmi)                 ->  did the OS read the monitor's EDID?

C:\ProLiant-ML10-Graphics-fix> Fix-Display.bat list
   1366x768 @ 60 Hz
   1280x720 @ 60 Hz
   1024x768 @ 60 Hz
    ...

C:\ProLiant-ML10-Graphics-fix> Fix-Display.bat set 1366 768
Setting \\.\DISPLAY1 to 1366x768 ...
Applied successfully.  (persisted to the registry)

C:\ProLiant-ML10-Graphics-fix> DisplayFix.exe --best
Best mode: 1366x768 @ 60 Hz
[+] \\.\DISPLAY1 set to 1366x768

# If only 640x480 / 1024x768 is available, the monitor's EDID is not reaching
# Windows -> use an ACTIVE DisplayPort -> HDMI adapter. See docs/06-windows-server.md
"""
panels.append(("06-windows", r"Windows Server / Windows  -  tools to run", win))

# ---- render ---------------------------------------------------------------
def esc(s):
    return html.escape(s, quote=False)

def make_html(title, body):
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  html,body {{ margin:0; padding:0; background:#11161d; }}
  .win {{ margin:0; background:#0f172a; border:1px solid #1f2a37; }}
  .bar {{ height:34px; background:#1b2431; display:flex; align-items:center;
          padding:0 12px; border-bottom:1px solid #2a3646; }}
  .dot {{ width:12px; height:12px; border-radius:50%; margin-right:8px; }}
  .r {{ background:#ff5f57; }} .y {{ background:#febc2e; }} .g {{ background:#28c840; }}
  .title {{ color:#9fb3c8; font:13px "DejaVu Sans Mono",monospace; margin-left:10px; }}
  pre {{ margin:0; padding:16px 18px; color:#dbe4ee;
         font:13px/1.45 "DejaVu Sans Mono","Consolas",monospace;
         white-space:pre; }}
  .prompt {{ color:#4ade80; }}
</style></head><body>
<div class="win">
  <div class="bar"><span class="dot r"></span><span class="dot y"></span>
  <span class="dot g"></span><span class="title">{esc(title)}</span></div>
  <pre>{esc(body)}</pre>
</div></body></html>"""

def shot(name, title, body):
    hpath = os.path.join(TMP, name + ".html")
    png = os.path.join(OUT, name + ".png")
    with open(hpath, "w", encoding="utf-8") as fh:
        fh.write(make_html(title, body))

    lines = body.split("\n")
    maxlen = max((len(l) for l in lines), default=40)
    width = int(min(2200, max(900, maxlen * 8.0 + 70)))
    height = int(34 + len(lines) * 19 + 34)

    cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
           "--hide-scrollbars", "--force-device-scale-factor=2",
           f"--window-size={width},{height}",
           f"--screenshot={png}", f"--user-data-dir={os.path.join(TMP,'chrome')}",
           "file://" + hpath]
    r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if r.returncode != 0 or not os.path.exists(png):
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                        "--hide-scrollbars",
                        f"--window-size={width},{height}",
                        f"--screenshot={png}",
                        f"--user-data-dir={os.path.join(TMP,'chrome')}",
                        "file://" + hpath],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"   {os.path.relpath(png, ROOT)}  ({width}x{height}@2x)")

for name, title, body in panels:
    shot(name, title, body)

shutil.rmtree(TMP, ignore_errors=True)
print("done.")
PY

echo
ls -lh "$OUT"
