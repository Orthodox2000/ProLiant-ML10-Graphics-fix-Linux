# Makefile for ProLiant-ML10-Graphics-fix
#
# Targets:
#   make            -> lint everything (syntax + shellcheck if available)
#   make windows    -> build scripts/windows/DisplayFix.exe (needs mingw-w64)
#   make lint       -> bash -n on all shell scripts
#   make shellcheck -> run shellcheck on all shell scripts (if installed)
#   make pdf        -> build docs/dist/ProLiant-ML10-Graphics-fix.pdf
#   make screenshots-> regenerate assets/screenshots/*.png
#   make banner     -> regenerate assets/social-preview.png
#   make social     -> regenerate assets/social/*.png
#   make docs       -> pdf + screenshots + banner + social
#   make install    -> install the Linux toolkit to /usr/local/sbin (needs root)
#   make uninstall  -> remove it
#   make clean      -> remove build artifacts

SHELL := /bin/bash
PREFIX ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin

LINUX_SH := $(wildcard scripts/linux/*.sh)
FREEBSD_SH := $(wildcard scripts/freebsd/*.sh)
DOC_SH := $(wildcard scripts/doc/*.sh)
ALL_SH := $(LINUX_SH) $(FREEBSD_SH) $(DOC_SH) install.sh

MINGW ?= x86_64-w64-mingw32-gcc
WIN_OUT := scripts/windows/DisplayFix.exe
WIN_SRC := scripts/windows/src/DisplayFix.c

.PHONY: all lint shellcheck windows pdf screenshots banner social docs install uninstall clean help

all: lint

## --- quality ---------------------------------------------------------------

lint:
	@echo ">> bash -n (syntax check)"
	@fail=0; for f in $(ALL_SH); do \
	  if bash -n "$$f"; then echo "   OK   $$f"; else echo "   FAIL $$f"; fail=1; fi; \
	done; exit $$fail

shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed; skipping"; exit 0; }
	shellcheck -S warning $(ALL_SH) || true

## --- windows ---------------------------------------------------------------

windows: $(WIN_OUT)

$(WIN_OUT): $(WIN_SRC)
	@command -v $(MINGW) >/dev/null 2>&1 || { \
	  echo "mingw-w64 not found. Install it:"; \
	  echo "  Debian/Ubuntu: sudo apt-get install -y mingw-w64"; \
	  echo "  Fedora:        sudo dnf install -y mingw64-gcc"; \
	  echo "  Arch:          sudo pacman -S mingw-w64-gcc"; \
	  exit 1; }
	$(MINGW) -O2 -municode -o $@ $< -luser32 -lgdi32 -lshell32
	@command -v x86_64-w64-mingw32-strip >/dev/null 2>&1 && x86_64-w64-mingw32-strip $@ || true
	@echo "Built $@"; sha256sum $@ 2>/dev/null || true

## --- documentation ---------------------------------------------------------

pdf:
	bash scripts/doc/build-pdf.sh

screenshots:
	bash scripts/doc/make-screenshots.sh

banner:
	bash scripts/doc/make-banner.sh

social:
	bash scripts/doc/make-social.sh

docs: pdf screenshots banner social

## --- install ---------------------------------------------------------------

install:
	install -d $(DESTDIR)$(SBINDIR)
	install -m 0755 scripts/linux/i915-display-fix.sh $(DESTDIR)$(SBINDIR)/i915-display-fix
	install -m 0755 scripts/linux/i915-collect.sh     $(DESTDIR)$(SBINDIR)/i915-collect
	@echo "Installed. Run: sudo i915-display-fix status"

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/i915-display-fix $(DESTDIR)$(SBINDIR)/i915-collect

## --- misc ------------------------------------------------------------------

clean:
	rm -f $(WIN_OUT)

help:
	@sed -n '2,13p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'
