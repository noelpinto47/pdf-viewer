#!/usr/bin/env bash
# Render PDF to multiple PNGs (one per page) under <project>/.zed/pdf-preview/<name>/
set -euo pipefail

if [[ $# -lt 1 ]] || [[ -z "$1" ]] || [[ "$1" == "/" ]]; then
  echo "Could not determine which PDF to preview." >&2
  exit 1
fi

RAW="$1"
if [[ ! -f "$RAW" ]]; then
  echo "PDF not found: $RAW" >&2
  exit 1
fi

PDF="$(cd "$(dirname "$RAW")" && pwd)/$(basename "$RAW")"
case "${PDF##*.}" in
  pdf | PDF) ;;
  *)
    echo "Not a PDF file: $PDF" >&2
    exit 1
    ;;
esac

MAX_PAGES="${2:-20}"
WORKTREE_ROOT="${3:-${ZED_WORKTREE_ROOT:-$(pwd)}}"
if [[ -z "$WORKTREE_ROOT" ]]; then
  WORKTREE_ROOT="$(pwd)"
fi
WORKTREE_ROOT="$(cd "$WORKTREE_ROOT" && pwd)"

preview_slug() {
  local base
  base="$(basename "$1" .pdf)"
  base="$(basename "$base" .PDF)"
  base="${base// /_}"
  echo "$base"
}

SLUG="$(preview_slug "$PDF")"
OUT_DIR="$WORKTREE_ROOT/.zed/pdf-preview/$SLUG"
mkdir -p "$WORKTREE_ROOT/.zed"
if [[ ! -f "$WORKTREE_ROOT/.zed/.gitignore" ]]; then
  printf '%s\n' 'pdf-preview/' 'current-pdf' >> "$WORKTREE_ROOT/.zed/.gitignore"
fi

mkdir -p "$OUT_DIR"

META="$OUT_DIR/.meta"
EXPECTED="$PDF|$MAX_PAGES"
CACHED=0

mapfile -t PAGES < <(ls "$OUT_DIR"/page*.png 2>/dev/null | sort -V)

# Reuse if: PNGs exist, same source PDF + page limit, and the PDF hasn't changed since
if [[ ${#PAGES[@]} -gt 0 && -f "$META" && "$(cat "$META")" == "$EXPECTED" && ! "$PDF" -nt "$META" ]]; then
  CACHED=1
  echo "Using cached preview for: $PDF"
else
  rm -f "$OUT_DIR"/*.png 2>/dev/null || true

  if command -v pdftoppm >/dev/null; then
    if [[ "$MAX_PAGES" == "0" ]]; then
      pdftoppm -png -r 144 "$PDF" "$OUT_DIR/page"
    else
      pdftoppm -png -r 144 -l "$MAX_PAGES" "$PDF" "$OUT_DIR/page"
    fi
  elif [[ "$(uname -s)" == "Darwin" ]] && command -v qlmanage >/dev/null; then
    qlmanage -t -s 2048 -o "$OUT_DIR" "$PDF" >/dev/null
    if [[ -f "$OUT_DIR/$(basename "$PDF").png" ]]; then
      mv "$OUT_DIR/$(basename "$PDF").png" "$OUT_DIR/page-001.png"
    fi
  else
    echo "Install poppler (brew install poppler) for multi-page previews." >&2
    exit 1
  fi

  mapfile -t PAGES < <(ls "$OUT_DIR"/page*.png 2>/dev/null | sort -V)
fi

if [[ ${#PAGES[@]} -eq 0 ]]; then
  echo "No preview images were created for: $PDF" >&2
  rm -rf "$OUT_DIR"
  exit 1
fi

PAGE_COUNT="${#PAGES[@]}"

{
  echo "pdf=$PDF"
  echo "pages=$PAGE_COUNT"
  echo "output_dir=$OUT_DIR"
  echo "open=${PAGES[0]}"
} >"$WORKTREE_ROOT/.zed/pdf-preview/last-preview.txt"

echo "Rendered $PAGE_COUNT page(s) → $OUT_DIR"
echo "Opening in Zed: ${PAGES[0]}"

if command -v zed >/dev/null; then
  zed "${PAGES[0]}"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  open -a Zed "${PAGES[0]}"
fi
