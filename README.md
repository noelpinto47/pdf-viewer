# PDF Viewer for Zed

Open and read PDFs while you work in [Zed](https://zed.dev/)—without leaving the editor for every glance at a paper, tutorial, or export.

Zed still shows **“Binary files are not supported”** when you click a `.pdf` tab. Extensions **cannot** register a real PDF tab yet—there is no preview/webview API ([discussion](https://github.com/zed-industries/zed/discussions/59598), [tracking issue](https://github.com/zed-industries/zed/issues/21208)). **PDF Viewer** is a viewer extension in intent: it renders pages to PNG and opens them in Zed’s built-in **image viewer** (split pane next to your code). Agent integration is optional, not the product name.

## Why it isn’t “open the PDF tab and scroll”

That behavior requires Zed core (or a custom preview API). Until that exists, every extension—including this one—works around the binary-file wall. Native PDF tabs today only exist in unofficial Zed forks (see [Limitations](#limitations-honest)).

## Quick start

### Install from GitHub (dev extension)

1. Clone this repo (or use your existing copy under `~/Documents/ZedExtensions/pdf-extension`).
2. In Zed: **Command Palette** → **`zed: install dev extension`** → select this folder.
3. Run **`scripts/preview-pdf.sh`** on your PDF (see below), or optionally enable **PDF Viewer** under Agent → context servers for preview commands.

### Install from the Zed extension registry

After publishing to the [Zed extension registry](https://github.com/zed-industries/extensions), install **PDF Viewer** from **Extensions**.

## View a PDF in Zed (recommended workflow)

### Option A — Shell script (primary)

```bash
chmod +x scripts/preview-pdf.sh
./scripts/preview-pdf.sh /path/to/TurtleBotTutorial.pdf
```

This creates PNGs beside the PDF and opens the first page in Zed. Split the editor (e.g. tutorial PDF preview on one side, notes on the other).

### Option B — Agent tools (optional)

| Tool | What it does |
|------|----------------|
| `pdf_render_preview` | Writes PNGs under `<pdf-dir>/.zed-pdf-preview/<name>/` |
| `pdf_open_first_page_in_zed` | Renders page 1 and opens it in Zed via the `zed` CLI |
| `pdf_extract_text` | Returns searchable text (great for papers and docs in Agent context) |

Example Agent prompt:

> Render a preview of `/Users/me/project/TurtleBotTutorial.pdf` and open the first page in Zed.

### Option C — Manual

1. Run `pdf_render_preview` (Agent) or `preview-pdf.sh`.
2. In the file tree, open `.zed-pdf-preview/.../page-001.png` (and further pages as needed).

Add `.zed-pdf-preview/` to `.gitignore` if you do not want previews in version control.

## Requirements

| Component | Purpose |
|-----------|---------|
| [Zed](https://zed.dev/) | Editor |
| [Rust (rustup)](https://rustup.rs/) + `wasm32-wasip2` | Builds the extension WASM |
| **Node.js 18+** | MCP server (Zed bundles Node for extensions) |
| **`pdftoppm`** (Poppler) | Best multi-page previews on Linux/Windows |
| **macOS** | Uses **`qlmanage`** (Quick Look) when Poppler is not installed—first page is reliable; install Poppler for all pages: `brew install poppler` |
| **`zed` CLI** (optional) | `pdf_open_first_page_in_zed` and `preview-pdf.sh`; install via Zed → **Command Palette** → **`zed: install cli`** |

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
- **macOS without Poppler** — Quick Look thumbnail is typically **one page**; install Poppler for full documents.
- **Scanned PDFs** — `pdf_extract_text` depends on embedded text; image-only pages need OCR elsewhere.
- **MCP in extensions** — Zed is moving toward the [official MCP registry](https://github.com/zed-industries/zed/issues/59351); this repo will publish the server there as well.

Community forks with **native** PDF tabs (unofficial, not this extension): [zed-with-pdf-viewer](https://github.com/TendonT52/zed-with-pdf-viewer), [kkpdf-zed](https://github.com/kk376/kkpdf-zed).

## Publishing checklist

- [ ] `npm publish` for package `pdf-viewer@0.1.0` (if publishing the server to npm for the extension host).
- [ ] Open a PR to [zed-industries/extensions](https://github.com/zed-industries/extensions) adding this repo as a submodule (see their [publishing guide](https://zed.dev/docs/extensions/publishing/publishing-guide)).
- [ ] Extension id **`pdf-viewer`**; if the registry only accepts MCP-only submissions for this feature set, Zed may require a preview API first—track [custom preview API](https://github.com/zed-industries/zed/discussions/59598).

## License

MIT — see [LICENSE](LICENSE).

## Author

Noel Pinto — [noelpinto47@gmail.com](mailto:noelpinto47@gmail.com)
