#!/usr/bin/env bash
# One-step PDF preview for Zed (binary PDF tabs have no ZED_FILE).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_PAGES="${MAX_PAGES:-20}"

worktree="${ZED_WORKTREE_ROOT:-${PWD:-}}"
worktree="$(cd "$worktree" && pwd)"

is_pdf() { [[ -f "$1" && "$1" =~ \.[pP][dD][fF]$ ]]; }

resolve_from_zed_vars() {
  local p=""
  if [[ -n "${ZED_RELATIVE_FILE:-}" ]]; then
    p="$worktree/$ZED_RELATIVE_FILE"
    is_pdf "$p" && echo "$p" && return 0
  fi
  if [[ -n "${ZED_FILE:-}" ]] && is_pdf "$ZED_FILE"; then
    echo "$ZED_FILE"
    return 0
  fi
  if [[ -n "${ZED_DIRNAME:-}" && -n "${ZED_FILENAME:-}" ]]; then
    p="${ZED_DIRNAME%/}/${ZED_FILENAME}"
    is_pdf "$p" && echo "$p" && return 0
  fi
  return 1
}

zed_window_title() {
  [[ "$(uname -s)" != "Darwin" ]] && return 1
  osascript -e 'tell application "System Events" to tell process "Zed" to get name of front window' 2>/dev/null || true
}

# Extract "name with spaces.pdf" from a window title like "name with spaces.pdf — project"
pdf_name_from_title() {
  local seg
  while IFS= read -r seg; do
    seg="$(printf '%s' "$seg" | sed 's/^[^[:alnum:]_.]*//; s/[[:space:]]*$//')"
    seg="${seg##*/}"
    if [[ "$seg" =~ \.[pP][dD][fF]$ ]]; then
      echo "$seg"
      return 0
    fi
  done < <(printf '%s\n' "$1" | sed 's/ — /\n/g; s/ - /\n/g')
  return 1
}

pick_one() {
  local -a c=("$@")
  if [[ ${#c[@]} -eq 1 ]]; then
    echo "${c[0]}"
    return 0
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    local -a rel=()
    local p choice
    for p in "${c[@]}"; do rel+=("${p#"$worktree"/}"); done
    choice="$(osascript -e 'on run argv
set r to choose from list argv with prompt "Select PDF to preview"
if r is false then error number -128
return item 1 of r
end run' "${rel[@]}" 2>/dev/null)" || return 1
    echo "$worktree/$choice"
    return 0
  fi

  if [[ -t 0 ]] && command -v fzf >/dev/null; then
    printf '%s\n' "${c[@]}" | fzf --prompt 'PDF preview> ' --height 40%
    return
  fi
  echo "Multiple matching PDFs found; cannot choose automatically:" >&2
  printf '  %s\n' "${c[@]}" >&2
  return 1
}

find_pdf_by_name() {
  local -a matches=()
  while IFS= read -r line; do
    matches+=("$line")
  done < <(find "$worktree" -type f -iname "$1" -not -path "*/.git/*" 2>/dev/null)
  [[ ${#matches[@]} -eq 0 ]] && return 1
  pick_one "${matches[@]}"
}

title="$(zed_window_title || true)"
title_hint=""
if [[ -n "$title" ]]; then
  title_hint="$(pdf_name_from_title "$title" 2>/dev/null || true)"
fi

pdf_path=""

# 1. Zed variables (only if they point at a PDF)
pdf_path="$(resolve_from_zed_vars 2>/dev/null || true)"

# 2. Focused window title
if [[ -z "$pdf_path" && -n "$title_hint" ]]; then
  pdf_path="$(find_pdf_by_name "$title_hint" || true)"
fi

# 3. Last resort: the project's only PDF, or an interactive pick. Never a cached one.
if [[ -z "$pdf_path" ]] && command -v fd >/dev/null; then
  mapfile -t all < <(fd -e pdf . "$worktree" 2>/dev/null)
  if [[ ${#all[@]} -gt 0 ]]; then
    pdf_path="$(pick_one "${all[@]}" || true)"
  fi
fi

if [[ -z "$pdf_path" ]] || ! is_pdf "$pdf_path"; then
  echo "Could not resolve the open PDF. Focus the PDF tab and retry, or allow Zed in Accessibility (macOS)." >&2
  [[ -n "$title" ]] && echo "Window title: $title" >&2
  exit 1
fi

exec "$SCRIPT_DIR/preview-pdf.sh" "$pdf_path" "$MAX_PAGES" "$worktree"
