import fsSync from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { AwilixContainer } from "awilix";
import type { Express } from "express";
import express from "express";

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

export function mountDevEndpoints(app: Express, container: AwilixContainer): void {
  // --- Filesystem browse API ---
  app.get("/api/browse", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev")
      return res.status(403).send("Forbidden: /api/browse only available in WORKBENCH_MODE=dev");
    const dir = (req.query.path as string) || os.homedir();
    let resolved = path.resolve(dir);
    for (let i = 0; i < 20; i++) {
      try {
        await fs.access(resolved);
        break;
      } catch {
        resolved = path.dirname(resolved);
      }
    }
    try {
      const parent = path.dirname(resolved);
      const entries = await fs.readdir(resolved, { withFileTypes: true });
      const dirs = entries
        .filter((e) => e.isDirectory() && !e.name.startsWith("."))
        .map((e) => e.name)
        .sort();
      const lines: string[] = [];
      lines.push(`<div class="folder-path" id="folder-current-path">${esc(resolved)}</div>`);
      lines.push(`<div class="folder-list">`);
      if (resolved !== parent)
        lines.push(
          `<a href="#" data-path="${esc(parent)}" class="folder-up"><span class="folder-icon">&#x2B06;</span> ..</a>`,
        );
      for (const d of dirs) {
        const full = path.join(resolved, d);
        lines.push(`<a href="#" data-path="${esc(full)}"><span class="folder-icon">&#x1F4C1;</span> ${esc(d)}</a>`);
      }
      if (dirs.length === 0) lines.push(`<div class="folder-empty">Aucun sous-dossier</div>`);
      lines.push(`</div>`);
      res.type("html").send(lines.join("\n"));
    } catch {
      res
        .type("html")
        .status(400)
        .send(`<p>Impossible de lire : <code>${esc(dir)}</code></p>`);
    }
  });

  // --- Static assets ---
  if (process.env.WORKBENCH_MODE === "dev") {
    const wsRoot = (() => {
      let dir = process.cwd();
      for (let i = 0; i < 10; i++) {
        if (fsSync.existsSync(path.join(dir, "modules"))) return dir;
        dir = path.dirname(dir);
      }
      return process.cwd();
    })();
    const devFrontend = path.join(wsRoot, "dev", "frontend");
    if (fsSync.existsSync(devFrontend)) app.use(express.static(devFrontend));
    const modulesDir = path.join(wsRoot, "modules");
    if (fsSync.existsSync(modulesDir)) {
      for (const entry of fsSync.readdirSync(modulesDir, { withFileTypes: true })) {
        if (entry.isDirectory()) {
          const modFrontend = path.join(modulesDir, entry.name, "frontend");
          if (fsSync.existsSync(modFrontend)) app.use(express.static(modFrontend));
        }
      }
    }
  }

  // --- Preview endpoint ---
  app.get("/preview", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev")
      return res.status(403).send("Forbidden: /preview only available in WORKBENCH_MODE=dev");
    const sql = (req.query.sql as string) || "";
    if (!sql) return res.status(400).send("Missing ?sql= parameter");
    const pool: import("pg").Pool = container.resolve("pool");
    try {
      const { rows } = await pool.query(`SELECT (${sql})::text AS html`);
      const html = rows[0]?.html ?? "";
      const page = `<!DOCTYPE html>
<html lang="fr" data-theme="light">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>pg_preview</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  <link rel="stylesheet" href="/pgview.css">
  <style>body { padding: 2rem; }</style>
</head>
<body>
  <main class="container">
    ${html}
  </main>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script>
    document.querySelectorAll('md').forEach(el => {
      const div = document.createElement('div');
      div.innerHTML = marked.parse(el.textContent);
      el.replaceWith(div);
    });
  </script>
</body>
</html>`;
      res.type("html").send(page);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      res
        .status(500)
        .type("html")
        .send(`<pre style="color:red">${esc(msg)}</pre>`);
    }
  });
}
