# Documentation build scripts

These regenerate the documentation artefacts in the repository.

| Script | Produces | Requires |
|---|---|---|
| [`build-pdf.sh`](build-pdf.sh) | `docs/dist/ProLiant-ML10-Graphics-fix.pdf` + an intermediate `.html` | `python3` with the `markdown` module, Google Chrome/Chromium |
| [`make-screenshots.sh`](make-screenshots.sh) | `assets/screenshots/*.png` | `python3`, Google Chrome/Chromium |
| [`make-banner.sh`](make-banner.sh) | `assets/social-preview.png` (1280×640) | Google Chrome/Chromium |

Both are also wired into the top-level `Makefile`:

```bash
make pdf          # rebuild the PDF
make screenshots  # rebuild the terminal screenshots
make banner       # rebuild the social-preview banner
make docs         # all three
```

## `build-pdf.sh`

Pipeline: **Markdown → HTML → PDF**, with no LaTeX or pandoc needed.

1. Every `README.md`, `QUICKSTART.md`, `docs/0*.md` and `CHANGELOG.md` is
   converted to HTML by `python3-markdown` (tables, fenced code, TOC).
2. The fragments are wrapped in one print-friendly stylesheet (A4, page breaks
   between documents, a cover page embedding `assets/architecture.svg`, and a
   contents list).
3. Headless Chrome prints it to PDF (`--print-to-pdf`).

Install the one dependency:

```bash
# Debian / Ubuntu / Mint
sudo apt-get install -y python3-markdown
# Fedora
sudo dnf install -y python3-markdown
```

## `make-screenshots.sh`

This script **runs the real commands on the current machine** and renders their
output inside a terminal window, then rasterises each panel with headless Chrome.
Nothing in the images is hand-written — rerun it after changing the tools and the
screenshots follow automatically.

> It is a doc generator, not a fixture: on a machine without an Intel GPU it will
> still produce images, but they will show that machine's (different) output.
> The committed PNGs are the reference-machine captures.
