# PDF Viewer for Zed

Open and read PDFs while you work in [Zed](https://zed.dev/)—without leaving the editor for every glance at a paper, tutorial, or export.

Zed still shows **“Binary files are not supported”** when you click a `.pdf` tab. Extensions **cannot** register a real PDF tab yet—there is no preview/webview API ([discussion](https://github.com/zed-industries/zed/discussions/59598), [tracking issue](https://github.com/zed-industries/zed/issues/21208)). **PDF Viewer** works around this: it renders each page to a PNG and opens the first page in Zed’s built-in **image viewer** (split pane next to your code). Agent integration is optional, not the product name.

## Why it isn’t “open the PDF tab and scroll”

That behavior requires Zed core (or a custom preview API). Until that exists, every extension—including this one—works around the binary-file wall. Native PDF tabs today only exist in unofficial Zed forks (see [Limitations](#limitations-honest)).

## Quick start

### Install from GitHub (dev extension)

1. Clone this repo (or use your existing copy under `~/Documents/ZedExtensions/pdf-extension`).
2. In Zed: **Command Palette** → **`zed: install dev extension`** → select this folder.
3. Add the Zed task below (recommended), or run `scripts/preview-pdf.sh` directly.

### Install from the Zed extension registry

After publishing to the [Zed extension registry](https://github.com/zed-industries/extensions), install **PDF Viewer** from **Extensions**.

## View a PDF in Zed (recommended workflow)

### Option A — Zed task (primary)

Focus the PDF tab and run the task. The script finds the PDF you have open, renders it, and opens **page 1**.

1. Make the scripts executable:

   ```bash
   chmod +x scripts/*.sh
   ```

2. Open your tasks file (**Command Palette** → **`zed: open tasks`** for global, or **`zed: open project tasks`** for `.zed/tasks.json`) and add:

   ```json
   {
     "label": "PDF: preview",
     "command": "/absolute/path/to/scripts/preview-pdf-zed-task.sh",
     "reveal": "never",
     "hide": "always",
     "use_new_terminal": false,
     "allow_concurrent_runs": false
   }
   ```

3. Run it via **Command Palette** → **`task: spawn`** → **PDF: preview** (or bind it to a key).

How the PDF is chosen (never from a previous run):

1. Zed environment variables, if they point to a `.pdf`.
2. The focused window title (macOS; requires Accessibility permission for Zed/your terminal).
3. Otherwise: the project’s only PDF, or a native macOS picker dialog if there are several (`fzf` on other systems, if a terminal is available).

Behavior:

- **Cached:** if PNGs for the PDF already exist and the PDF hasn’t changed, they are reused instead of regenerated.
- **Output:** one PNG per page under `<project>/.zed/pdf-preview/<pdf-name>/`. Only the first page opens automatically; open other pages from the file tree.
- **Page limit:** 20 pages by default. Set `MAX_PAGES=0` for all pages, or any other number to change the limit.

### Option B — Shell script

```bash
./scripts/preview-pdf.sh /path/to/TurtleBotTutorial.pdf [max_pages] [project_root]
```

Renders the PDF (or reuses the cache) and opens page 1 in Zed.

### Option C — Agent tools (optional)

| Tool | What it does |
|------|----------------|
| `pdf_render_preview` | Writes PNGs under `<pdf-dir>/.zed-pdf-preview/<name>/` |
| `pdf_open_first_page_in_zed` | Renders page 1 and opens it in Zed via the `zed` CLI |
| `pdf_extract_text` | Returns searchable text (great for papers and docs in Agent context) |

Example Agent prompt:

> Render a preview of `/Users/me/project/TurtleBotTutorial.pdf` and open the first page in Zed.

The scripts add `pdf-preview/` to `.zed/.gitignore` automatically. If you use the Agent tools, add `.zed-pdf-preview/` to your `.gitignore` yourself.

## Requirements

| Component | Purpose |
|-----------|---------|
| [Zed](https://zed.dev/) | Editor |
| [Rust (rustup)](https://rustup.rs/) + `wasm32-wasip2` | Builds the extension WASM |
| **Node.js 18+** | MCP server (Zed bundles Node for extensions) |
| **`pdftoppm`** (Poppler) | Multi-page previews: `brew install poppler` |
| **macOS** | Falls back to **`qlmanage`** (Quick Look) if Poppler is missing—first page only. Uses `osascript` for the PDF picker dialog |
| **`zed` CLI** | Opens the preview image; install via Zed → **Command Palette** → **`zed: install cli`** |
| `fd`, `fzf` (optional) | PDF discovery / picker fallback on non-macOS systems |

ImageMagick is **not** required.

## Development

```bash
# Extension WASM
cargo build --target wasm32-wasip2 --release

# MCP server (local)
npm install
npm run check   # if you add a check script; or:
node mcp-server/index.js   # stdio MCP — expect idle on stdin

# Debug extension logs
zed --foreground
```

### Local MCP without npm publish

Point Zed at the checkout:

```json
"context_servers": {
  "pdf-viewer": {
    "command": "node",
    "args": ["/absolute/path/to/pdf-viewer/mcp-server/index.js"]
  }
}
```

The dev extension normally runs the server via `npx` (`npm` package or `github:noelpinto47/pdf-viewer`).

## Limitations (honest)

- **Not a native PDF tab** — previews are PNGs until Zed adds a preview/webview API or built-in PDF viewer.
- **Separate page images** — each page is its own PNG; there is no single scrolling image.
- **Brief terminal flash** — Zed tasks always run in a terminal tab. `reveal: never` and `hide: always` minimize it, but it may still flash briefly.
- **macOS without Poppler** — Quick Look gives **one page**; install Poppler for full documents.
- **Window-title detection** — macOS only, and needs Accessibility permission. Without it, the script falls back to Zed variables and the picker.
- **Scanned PDFs** — `pdf_extract_text` depends on embedded text; image-only pages need OCR elsewhere.
- **MCP in extensions** — Zed is moving toward the [official MCP registry](https://github.com/zed-industries/zed/issues/59351); this repo will publish the server there as well.

Community forks with **native** PDF tabs (unofficial, not this extension): [zed-with-pdf-viewer](https://github.com/TendonT52/zed-with-pdf-viewer), [kkpdf-zed](https://github.com/kk376/kkpdf-zed).

## License

MIT — see [LICENSE](LICENSE).

## Author

Noel Pinto — [noelpinto47@gmail.com](mailto:noelpinto47@gmail.com)
