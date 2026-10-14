#!/usr/bin/env bash
#
# make-banner.sh - render the repository social-preview / README banner.
#
# Produces a 1280x640 PNG (GitHub's recommended social-preview size).
# Needs: Google Chrome / Chromium.
#
# Usage:  bash scripts/doc/make-banner.sh
# Output: assets/social-preview.png
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$ROOT/assets/social-preview.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done
[ -n "$CHROME" ] || { echo "Chrome/Chromium not found." >&2; exit 1; }

cat > "$TMP/banner.html" <<'HTML'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { width: 1280px; height: 640px; overflow: hidden; }
  body {
    font-family: "DejaVu Sans", Arial, sans-serif; color: #e6edf5;
    background:
      radial-gradient(1200px 500px at 85% -10%, #14406b 0%, rgba(20,64,107,0) 60%),
      radial-gradient(900px 500px at 5% 110%, #0b3d2e 0%, rgba(11,61,46,0) 55%),
      linear-gradient(135deg, #070b14 0%, #0b1220 55%, #0a1626 100%);
    padding: 54px 64px; position: relative;
  }
  .grid { position: absolute; inset: 0; opacity: .10;
    background-image: linear-gradient(#3b82f6 1px, transparent 1px),
                      linear-gradient(90deg, #3b82f6 1px, transparent 1px);
    background-size: 40px 40px; }
  .content { position: relative; }
  .kicker { font-size: 17px; letter-spacing: 3px; color: #7dd3fc;
            text-transform: uppercase; font-weight: 700; }
  h1 { font-size: 60px; line-height: 1.03; margin: 12px 0 6px; font-weight: 800;
       color: #ffffff; }
  h1 .accent { color: #38bdf8; }
  .sub { font-size: 25px; color: #b9c7d6; margin-bottom: 26px; font-weight: 400; }
  .chain { display: flex; align-items: center; gap: 14px; margin: 8px 0 24px;
           font-family: "DejaVu Sans Mono", monospace; font-size: 20px; }
  .node { background: #0f2036; border: 1px solid #21456e; color: #d6e4f5;
          padding: 8px 16px; border-radius: 9px; }
  .arrow { color: #5b7290; }
  .bad { color: #f87171; font-weight: 700; }
  .good { color: #4ade80; font-weight: 700; }
  .chips { display: flex; gap: 12px; margin-bottom: 26px; }
  .chip { font-size: 17px; padding: 7px 15px; border-radius: 999px;
          border: 1px solid #2b4a72; background: rgba(56,189,248,.08);
          color: #cfe6fb; }
  .stats { font-size: 19px; color: #9fb3c8; font-family: "DejaVu Sans Mono", monospace; }
  .stats b { color: #ffffff; }
  .url { position: absolute; right: 64px; bottom: 52px; text-align: right; }
  .url .repo { font-size: 18px; color: #7dd3fc; font-family: "DejaVu Sans Mono", monospace; }
  .url .lic { font-size: 15px; color: #64748b; margin-top: 6px; }
  .gpu { position:absolute; right:64px; top:58px; text-align:right; }
  .gpu .t { font-size:16px; color:#93a7bd; }
  .gpu .v { font-size:22px; color:#fff; font-weight:700; }
</style></head>
<body>
  <div class="grid"></div>
  <div class="gpu">
    <div class="t">onboard GPU</div>
    <div class="v">Intel HD Graphics P530</div>
  </div>
  <div class="content">
    <div class="kicker">HP ProLiant ML10 Gen9</div>
    <h1>Graphics &amp; <span class="accent">Display Fix</span></h1>
    <div class="sub">No signal / black screen over DisplayPort&nbsp;&rarr;&nbsp;HDMI &mdash; solved.</div>

    <div class="chain">
      <span class="node">DP++</span><span class="arrow">&rarr;</span>
      <span class="node">DVI</span><span class="arrow">&rarr;</span>
      <span class="node">HDMI</span>
      <span class="bad">&#10007; EDID dropped</span>
      <span class="arrow">&nbsp;&nbsp;|&nbsp;&nbsp;</span>
      <span class="good">&#10003; fixed</span>
    </div>

    <div class="chips">
      <span class="chip">Linux (GRUB / systemd-boot)</span>
      <span class="chip">Windows Server</span>
      <span class="chip">FreeBSD</span>
      <span class="chip">.exe &amp; scripts</span>
    </div>

    <div class="stats">
      <b>1366&times;768 @ 60&nbsp;Hz</b> &nbsp;&middot;&nbsp; i915 + hardware acceleration
      &nbsp;&middot;&nbsp; root cause &amp; fix
    </div>
  </div>

  <div class="url">
    <div class="repo">github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux</div>
    <div class="lic">MIT License &middot; tested &amp; documented</div>
  </div>
</body></html>
HTML

echo ">> rendering banner with $CHROME ..."
"$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1280,640 \
  --user-data-dir="$TMP/chrome" --screenshot="$OUT" \
  "file://$TMP/banner.html" >/dev/null 2>&1 \
  || "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
       --window-size=1280,640 --user-data-dir="$TMP/chrome" --screenshot="$OUT" \
       "file://$TMP/banner.html" >/dev/null 2>&1

if [ -s "$OUT" ]; then
  echo ">> done: $OUT"
  file "$OUT"
else
  echo "!! banner generation failed" >&2
  exit 1
fi
