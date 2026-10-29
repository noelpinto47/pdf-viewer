#!/usr/bin/env bash
# Render a PDF to PNG previews beside the file (for Zed's built-in image viewer).
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: preview-pdf.sh /path/to/file.pdf [max_pages]" >&2
  exit 1
fi

PDF="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
MAX_PAGES="${2:-20}"
OUT_DIR="$(dirname "$PDF")/.zed-pdf-preview/$(basename "$PDF" .pdf)"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png 2>/dev/null || true

if command -v pdftoppm >/dev/null; then
  pdftoppm -png -r 144 "$PDF" "$OUT_DIR/page"
  mapfile -t PAGES < <(ls "$OUT_DIR"/page*.png 2>/dev/null | sort)
elif [[ "$(uname -s)" == "Darwin" ]] && command -v qlmanage >/dev/null; then
  qlmanage -t -s 2048 -o "$OUT_DIR" "$PDF" >/dev/null
  if [[ -f "$OUT_DIR/$(basename "$PDF").png" ]]; then
    mv "$OUT_DIR/$(basename "$PDF").png" "$OUT_DIR/page-001.png"
  fi
  mapfile -t PAGES < <(ls "$OUT_DIR"/*.png 2>/dev/null | sort)
else
  echo "Install poppler (pdftoppm) or run on macOS with qlmanage available." >&2
  exit 1
fi

if [[ ${#PAGES[@]} -eq 0 ]]; then
  echo "No preview images were created." >&2
  exit 1
fi

if [[ "$MAX_PAGES" -gt 0 ]] && [[ ${#PAGES[@]} -gt "$MAX_PAGES" ]]; then
  PAGES=("${PAGES[@]:0:MAX_PAGES}")
fi

FIRST="${PAGES[0]}"
echo "Wrote ${#PAGES[@]} page image(s) under: $OUT_DIR"
echo "Opening first page in Zed: $FIRST"

if command -v zed >/dev/null; then
  zed "$FIRST"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  open -a Zed "$FIRST"
else
  echo "Add the zed CLI to PATH, or open manually: $FIRST"
fi
