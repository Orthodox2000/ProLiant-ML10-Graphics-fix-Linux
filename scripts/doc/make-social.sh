#!/usr/bin/env bash
#
# make-social.sh - render LinkedIn / social sharing images for the project.
#
# Produces:
#   assets/linkedin/linkedin-1200x627.png   landscape (link preview / feed)
#   assets/linkedin/linkedin-1080x1080.png  square    (feed post)
#
# Needs: Google Chrome / Chromium.
#
# Usage:  bash scripts/doc/make-social.sh
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUTDIR="$ROOT/assets/linkedin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done
[ -n "$CHROME" ] || { echo "Chrome/Chromium not found." >&2; exit 1; }

mkdir -p "$OUTDIR"

# $1=width  $2=height  $3=output file
render() {
  local W="$1" H="$2" OUT="$3" HTML="$TMP/$1x$2.html"

  cat > "$HTML" <<HTMLDOC
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body {
    font-family: "DejaVu Sans", Arial, sans-serif; color: #e6edf5;
    background:
      radial-gradient(1100px 460px at 88% -12%, #14406b 0%, rgba(20,64,107,0) 60%),
      radial-gradient(820px 460px at 4% 112%, #0b3d2e 0%, rgba(11,61,46,0) 55%),
      linear-gradient(135deg, #070b14 0%, #0b1220 55%, #0a1626 100%);
    display: flex; flex-direction: column; justify-content: space-between;
    padding: 5.5vmin 6vmin; position: relative;
  }
  .grid { position: absolute; inset: 0; opacity: .10;
    background-image: linear-gradient(#3b82f6 1px, transparent 1px),
                      linear-gradient(90deg, #3b82f6 1px, transparent 1px);
    background-size: 6.5vmin 6.5vmin; }
  .z { position: relative; }
  .kicker { font-size: clamp(13px, 2.4vmin, 27px); letter-spacing: .26em;
            color: #7dd3fc; text-transform: uppercase; font-weight: 700; }
  h1 { font-size: clamp(30px, 8.6vmin, 104px); line-height: 1.02;
       font-weight: 800; color: #ffffff; margin: .22em 0 0; }
  h1 .accent { color: #38bdf8; }
  .sub { font-size: clamp(15px, 3.2vmin, 40px); color: #b9c7d6; margin-top: .55em; }
  .chain { display: flex; flex-wrap: wrap; align-items: center; gap: 1.3vmin;
           font-family: "DejaVu Sans Mono", monospace;
           font-size: clamp(12px, 2.5vmin, 30px); }
  .node { background: #0f2036; border: 1px solid #21456e; color: #d6e4f5;
          padding: .32em .68em; border-radius: .5em; }
  .arrow { color: #5b7290; }
  .bad   { color: #f87171; font-weight: 700; }
  .good  { color: #4ade80; font-weight: 700; }
  .chips { display: flex; flex-wrap: wrap; gap: 1.3vmin; }
  .chip { font-size: clamp(12px, 2.4vmin, 28px); padding: .34em .8em;
          border-radius: 999px; border: 1px solid #2b4a72;
          background: rgba(56,189,248,.08); color: #cfe6fb; }
  .stats { font-size: clamp(13px, 2.7vmin, 32px); color: #9fb3c8;
           font-family: "DejaVu Sans Mono", monospace; }
  .stats b { color: #ffffff; }
  .url { font-size: clamp(11px, 2.3vmin, 26px); color: #7dd3fc; margin-top: .5em;
         font-family: "DejaVu Sans Mono", monospace; }
  .lic { font-size: clamp(10px, 1.9vmin, 21px); color: #64748b; margin-top: .35em; }
</style></head>
<body>
  <div class="grid"></div>

  <div class="z">
    <div class="kicker">HP ProLiant ML10 Gen9</div>
    <h1>Black screen on<br><span class="accent">DisplayPort&rarr;HDMI?</span></h1>
    <div class="sub">Root-caused and fixed &mdash; native resolution, with acceleration.</div>
  </div>

  <div class="chain z">
    <span class="node">DP++</span><span class="arrow">&rarr;</span>
    <span class="node">DVI</span><span class="arrow">&rarr;</span>
    <span class="node">HDMI</span>
    <span class="bad">&#10007; EDID dropped</span>
    <span class="arrow">&nbsp;|&nbsp;</span>
    <span class="good">&#10003; fixed</span>
  </div>

  <div class="chips z">
    <span class="chip">Linux (GRUB / systemd-boot)</span>
    <span class="chip">Windows Server</span>
    <span class="chip">FreeBSD</span>
    <span class="chip">DisplayFix.exe</span>
  </div>

  <div class="z">
    <div class="stats"><b>1366&times;768 @ 60&nbsp;Hz</b> &middot; i915 + hardware acceleration</div>
    <div class="url">github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux</div>
    <div class="lic">MIT License &middot; documented &amp; tested</div>
  </div>
</body></html>
HTMLDOC

  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="${W},${H}" \
    --user-data-dir="$TMP/chrome-$W" --screenshot="$OUT" \
    "file://$HTML" >/dev/null 2>&1 \
    || "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
         --force-device-scale-factor=1 --window-size="${W},${H}" \
         --user-data-dir="$TMP/chrome-$W" --screenshot="$OUT" \
         "file://$HTML" >/dev/null 2>&1

  if [ -s "$OUT" ]; then
    echo ">> $OUT"
    file "$OUT"
  else
    echo "!! failed to render $OUT" >&2
    return 1
  fi
}

echo ">> rendering LinkedIn images with $CHROME ..."
render 1200 627  "$OUTDIR/linkedin-1200x627.png"
render 1080 1080 "$OUTDIR/linkedin-1080x1080.png"
echo ">> done."
