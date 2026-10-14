#!/usr/bin/env bash
#
# build-pdf.sh - build a single, print-friendly PDF from the Markdown docs.
#
# Pipeline:  Markdown --(python3-markdown)--> HTML --(headless Chrome)--> PDF
# No LaTeX/pandoc required. Needs: python3 with the `markdown` module,
# and Google Chrome / Chromium.
#
# Usage:
#   bash scripts/doc/build-pdf.sh [output-dir]
# Default output dir: docs/dist/
#
# Part of the ProLiant-ML10-Graphics-fix repository (MIT).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUTDIR="${1:-$ROOT/docs/dist}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUTDIR"

BASENAME="ProLiant-ML10-Graphics-fix"

FILES=(
  README.md
  QUICKSTART.md
  docs/01-problem-statement.md
  docs/02-diagnosis-and-evidence.md
  docs/03-root-cause.md
  docs/04-linux-solution.md
  docs/05-distro-guide.md
  docs/06-windows-server.md
  docs/07-other-os.md
  docs/08-hardware-cables-adapters.md
  docs/09-troubleshooting.md
  docs/10-verification.md
  docs/11-reference.md
  docs/12-faq.md
  CHANGELOG.md
)

echo ">> converting Markdown to HTML ..."
python3 - "$ROOT" "$TMP/doc.html" "${FILES[@]}" <<'PY'
import sys, os, html, datetime
try:
    import markdown
except ImportError:
    sys.exit("python3 'markdown' module is required:  apt install python3-markdown")

root, outpath = sys.argv[1], sys.argv[2]
files = sys.argv[3:]

md = markdown.Markdown(extensions=[
    "fenced_code", "tables", "sane_lists", "attr_list",
    "toc", "md_in_html", "def_list",
])

sections, toc = [], []
for rel in files:
    path = os.path.join(root, rel)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    md.reset()
    body = md.convert(text)

    title = rel
    for line in text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    anchor = "doc-" + rel.replace("/", "-").replace(".md", "").replace(".", "-")
    toc.append((anchor, title))
    sections.append(f'<section id="{anchor}" class="doc">\n{body}\n</section>')

toc_html = "\n".join(
    f'<li><a href="#{a}">{html.escape(t)}</a></li>' for a, t in toc
)

date = datetime.date.today().isoformat()
doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<base href="file://{root}/">
<title>HP ProLiant ML10 Gen9 - Graphics / Display Fix</title>
<style>
  @page {{ size: A4; margin: 16mm 15mm 18mm 15mm; }}
  html {{ font-size: 10.5pt; }}
  body {{ font-family: "DejaVu Sans", Arial, sans-serif; color: #1b1b1b;
         line-height: 1.45; margin: 0; }}
  h1, h2, h3, h4 {{ font-family: "DejaVu Sans", Arial, sans-serif;
                    color: #102a43; line-height: 1.2; }}
  h1 {{ font-size: 20pt; border-bottom: 2px solid #0d6efd; padding-bottom: 4px; }}
  h2 {{ font-size: 15pt; margin-top: 1.4em; border-bottom: 1px solid #cbd5e1;
        padding-bottom: 2px; }}
  h3 {{ font-size: 12.5pt; margin-top: 1.1em; }}
  code, pre, kbd {{ font-family: "DejaVu Sans Mono", "Courier New", monospace; }}
  code {{ background: #f1f3f5; padding: 0 3px; border-radius: 3px; font-size: 0.92em; }}
  pre {{ background: #0f172a; color: #e2e8f0; padding: 10px 12px;
         border-radius: 6px; overflow-x: auto; font-size: 8.6pt; line-height: 1.35;
         page-break-inside: avoid; }}
  pre code {{ background: none; color: inherit; padding: 0; }}
  table {{ border-collapse: collapse; width: 100%; margin: 0.7em 0;
           font-size: 9pt; page-break-inside: avoid; }}
  th, td {{ border: 1px solid #cbd5e1; padding: 4px 7px; text-align: left;
            vertical-align: top; }}
  th {{ background: #e8f0fe; }}
  tr:nth-child(even) td {{ background: #f8fafc; }}
  blockquote {{ margin: 0.7em 0; padding: 6px 12px; border-left: 4px solid #0d6efd;
                background: #f1f5f9; color: #334155; }}
  a {{ color: #0d6efd; text-decoration: none; }}
  img, svg {{ max-width: 100%; }}
  hr {{ border: none; border-top: 1px solid #cbd5e1; margin: 1.4em 0; }}
  .doc {{ page-break-before: always; }}
  .cover {{ text-align: center; padding-top: 40mm; }}
  .cover h1 {{ border: none; font-size: 28pt; color: #0d6efd; }}
  .cover .sub {{ font-size: 13pt; color: #334155; margin-top: 6px; }}
  .cover .meta {{ margin-top: 28mm; font-size: 10pt; color: #64748b; }}
  .cover img {{ width: 92%; margin-top: 14mm; }}
  .toc {{ page-break-before: always; }}
  .toc ol {{ font-size: 11pt; line-height: 1.7; }}
  .toc a {{ color: #102a43; }}
</style>
</head>
<body>
<div class="cover">
  <h1>HP ProLiant ML10 Gen9</h1>
  <div class="sub">Graphics &amp; Display Fix &mdash; Linux, Windows Server &amp; more</div>
  <div class="sub" style="font-size:11pt;color:#475569">
    Intel HD Graphics P530 &nbsp;&bull;&nbsp; DP&rarr;DVI&rarr;HDMI &nbsp;&bull;&nbsp;
    root cause, fix, scripts, verification
  </div>
  <img src="assets/architecture.svg" alt="signal chain diagram">
  <div class="meta">
    Generated {date}<br>
    https://github.com/Orthodox2000/ProLiant-ML10-Graphics-fix-Linux<br>
    MIT License
  </div>
</div>

<div class="toc">
  <h1>Contents</h1>
  <ol>
  {toc_html}
  </ol>
</div>

{''.join(sections)}
</body>
</html>"""

with open(outpath, "w", encoding="utf-8") as fh:
    fh.write(doc)
print(f"   wrote {outpath}")
PY

cp "$TMP/doc.html" "$OUTDIR/$BASENAME.html"

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done
[ -n "$CHROME" ] || { echo "!! Google Chrome / Chromium not found; HTML written to $OUTDIR/$BASENAME.html" >&2; exit 1; }

echo ">> rendering PDF with $CHROME ..."
FLAGS=(--headless=new --disable-gpu --no-sandbox --no-pdf-header-footer
       --virtual-time-budget=10000 --run-all-compositor-stages-before-draw
       --user-data-dir="$TMP/chrome")
"$CHROME" "${FLAGS[@]}" \
  --print-to-pdf="$OUTDIR/$BASENAME.pdf" \
  "file://$TMP/doc.html" >/dev/null 2>&1 \
  || "$CHROME" --headless --disable-gpu --no-sandbox --no-pdf-header-footer \
       --user-data-dir="$TMP/chrome" \
       --print-to-pdf="$OUTDIR/$BASENAME.pdf" "file://$TMP/doc.html" >/dev/null 2>&1

if [ -s "$OUTDIR/$BASENAME.pdf" ]; then
  echo ">> done:"
  ls -lh "$OUTDIR/$BASENAME.pdf" "$OUTDIR/$BASENAME.html"
else
  echo "!! PDF generation failed. The HTML is at $OUTDIR/$BASENAME.html" >&2
  exit 1
fi
