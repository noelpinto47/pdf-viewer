#!/usr/bin/env bash
# Invoked from Zed tasks. Reads ZED_* from the environment (no path args — avoids spawn filtering + spaces).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_PAGES="${MAX_PAGES:-20}"

pdf_path="${ZED_FILE:-}"
worktree="${ZED_WORKTREE_ROOT:-}"

if [[ -z "$pdf_path" && -n "${ZED_DIRNAME:-}" && -n "${ZED_FILENAME:-}" ]]; then
  pdf_path="${ZED_DIRNAME}/${ZED_FILENAME}"
fi

if [[ -z "$worktree" ]]; then
  worktree="$(pwd)"
fi

if [[ -z "$pdf_path" ]]; then
  echo "Could not determine which PDF to preview." >&2
  echo "Focus the PDF tab (with a project folder open), then run PDF: preview again." >&2
  exit 1
fi

exec "$SCRIPT_DIR/preview-pdf.sh" "$pdf_path" "$MAX_PAGES" "$worktree"
