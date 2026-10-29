#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import path from "node:path";
import * as z from "zod/v4";

const execFileAsync = promisify(execFile);

const PREVIEW_DIR_NAME = ".zed/pdf-preview";

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function resolvePdfPath(inputPath) {
  const resolved = path.resolve(inputPath);
  if (!(await pathExists(resolved))) {
    throw new Error(`File not found: ${resolved}`);
  }
  if (path.extname(resolved).toLowerCase() !== ".pdf") {
    throw new Error(`Not a PDF file: ${resolved}`);
  }
  return resolved;
}

async function extractText(pdfPath, maxPages = 50) {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const data = new Uint8Array(await fs.readFile(pdfPath));
  const doc = await pdfjs.getDocument({ data, useSystemFonts: true }).promise;
  const limit = Math.min(doc.numPages, maxPages);
  const chunks = [];

  for (let pageNum = 1; pageNum <= limit; pageNum++) {
    const page = await doc.getPage(pageNum);
    const content = await page.getTextContent();
    const text = content.items
      .map((item) => ("str" in item ? item.str : ""))
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    chunks.push(`--- Page ${pageNum} ---\n${text}`);
  }

  const truncated = doc.numPages > limit;
  return {
    numPages: doc.numPages,
    pagesExtracted: limit,
    truncated,
    text: chunks.join("\n\n"),
  };
}

async function renderWithPdftoppm(pdfPath, outDir, dpi) {
  const prefix = path.join(outDir, "page");
  await execFileAsync("pdftoppm", ["-png", "-r", String(dpi), pdfPath, prefix], {
    maxBuffer: 32 * 1024 * 1024,
  });
  const files = (await fs.readdir(outDir))
    .filter((f) => f.startsWith("page") && f.endsWith(".png"))
    .sort();
  return files.map((f) => path.join(outDir, f));
}

async function renderWithQlmanage(pdfPath, outDir, scale) {
  await fs.mkdir(outDir, { recursive: true });
  await execFileAsync("qlmanage", ["-t", "-s", String(scale), "-o", outDir, pdfPath], {
    maxBuffer: 32 * 1024 * 1024,
  });
  const base = path.basename(pdfPath);
  const generated = path.join(outDir, `${base}.png`);
  if (await pathExists(generated)) {
    const target = path.join(outDir, "page-001.png");
    await fs.rename(generated, target);
    return [target];
  }
  const pngs = (await fs.readdir(outDir)).filter((f) => f.endsWith(".png")).sort();
  return pngs.map((f) => path.join(outDir, f));
}

async function renderPages(pdfPath, { dpi = 144, maxPages = 20 } = {}) {
  const pdfPathResolved = await resolvePdfPath(pdfPath);
  const outDir = path.join(
    path.dirname(pdfPathResolved),
    PREVIEW_DIR_NAME,
    path.basename(pdfPathResolved, ".pdf"),
  );
  await fs.rm(outDir, { recursive: true, force: true });
  await fs.mkdir(outDir, { recursive: true });

  let images = [];
  const hasPdftoppm = await execFileAsync("which", ["pdftoppm"])
    .then(() => true)
    .catch(() => false);

  if (hasPdftoppm) {
    images = await renderWithPdftoppm(pdfPathResolved, outDir, dpi);
  } else if (process.platform === "darwin") {
    images = await renderWithQlmanage(pdfPathResolved, outDir, Math.min(4096, dpi * 14));
  } else {
    throw new Error(
      "Install poppler (pdftoppm) for multi-page previews, or use macOS Quick Look (qlmanage).",
    );
  }

  if (maxPages > 0) {
    images = images.slice(0, maxPages);
  }

  return {
    pdfPath: pdfPathResolved,
    outputDirectory: outDir,
    pageImages: images,
    openInZedHint:
      images.length > 0
        ? `Open in Zed: zed ${JSON.stringify(images[0])} (split pane beside your project).`
        : "No pages rendered.",
  };
}

const server = new McpServer({
  name: "pdf-viewer",
  version: "0.1.0",
});

server.registerTool(
  "pdf_extract_text",
  {
    description: "Extract plain text from a PDF file for reading or Agent context.",
    inputSchema: {
      path: z.string().describe("Absolute path to the PDF file."),
      max_pages: z.number().optional().describe("Maximum pages to extract (default 50)."),
    },
  },
  async ({ path: pdfPath, max_pages: maxPages }) => {
    const resolved = await resolvePdfPath(pdfPath);
    const result = await extractText(resolved, maxPages ?? 50);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ path: resolved, ...result }, null, 2),
        },
      ],
    };
  },
);

server.registerTool(
  "pdf_render_preview",
  {
    description:
      "Render PDF pages to PNG files beside the PDF. Open the PNGs in Zed to view the document.",
    inputSchema: {
      path: z.string().describe("Absolute path to the PDF file."),
      dpi: z
        .number()
        .optional()
        .describe("Resolution for pdftoppm (default 144). On macOS, Quick Look scale is used instead."),
      max_pages: z
        .number()
        .optional()
        .describe("Cap rendered pages (default 20, 0 = no cap)."),
    },
  },
  async ({ path: pdfPath, dpi, max_pages: maxPages }) => {
    const result = await renderPages(pdfPath, {
      dpi: dpi ?? 144,
      maxPages: maxPages ?? 20,
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  },
);

server.registerTool(
  "pdf_open_first_page_in_zed",
  {
    description:
      "Render the first page and launch Zed on the PNG preview (requires the zed CLI on PATH).",
    inputSchema: {
      path: z.string().describe("Absolute path to the PDF file."),
    },
  },
  async ({ path: pdfPath }) => {
    const result = await renderPages(pdfPath, { dpi: 144, maxPages: 1 });
    if (result.pageImages.length === 0) {
      throw new Error("No preview image was generated.");
    }
    const imagePath = result.pageImages[0];
    await execFileAsync("zed", [imagePath]).catch(async () => {
      await execFileAsync("open", ["-a", "Zed", imagePath]);
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ opened: imagePath, ...result }, null, 2),
        },
      ],
    };
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
