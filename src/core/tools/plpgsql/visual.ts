import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createVisualTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_visual",
      description:
        "Visual testing via Playwright headless. Crawls module pages, takes screenshots, " +
        "tests POST actions (forms + data-rpc buttons), detects HTTP errors, JS console errors, empty pages.\n" +
        "Requires: make dev-up (nginx on 8080). QA seed recommended for test data.\n" +
        "Screenshots saved to data/screenshots/{schema}/.",
      schema: z.object({
        schema: z.string().describe("Schema, comma-separated, or * for all modules. Ex: crm or crm,quote or *"),
        base_url: z.string().default("http://localhost:8080").describe("Dev stack base URL"),
        depth: z.number().default(2).describe("Max crawl depth from index (default: 2)"),
        post: z.boolean().default(true).describe("Test POST actions: fill forms + click buttons (default: true)"),
      }),
    },
    handler: async (args) => {
      const schemaArg = args.schema as string;
      const baseUrl = (args.base_url as string).replace(/\/$/, "");
      const maxDepth = args.depth as number;
      const testPost = args.post as boolean;

      // 1. Resolve schemas
      const schemas =
        schemaArg === "*"
          ? await withClient(async (client) => {
              const r = await client.query<{ s: string }>(
                `SELECT DISTINCT n.nspname AS s FROM pg_proc p
                 JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE p.proname = 'nav_items'
                   AND n.nspname NOT LIKE '%\\_ut' AND n.nspname NOT LIKE '%\\_qa'
                   AND n.nspname != 'pgv'
                 ORDER BY 1`,
              );
              return r.rows.map((r) => r.s);
            })
          : schemaArg.split(",").map((s) => s.trim());

      if (!schemas.length) return text("no modules with nav_items() found");

      // 2. Launch Playwright
      let pw: any;
      try {
        pw = await import("playwright");
      } catch {
        return text("playwright not available.\nInstall: npm install -D playwright && npx playwright install chromium");
      }

      let browser: any;
      try {
        browser = await pw.chromium.launch({ headless: true });
      } catch {
        return text("chromium not installed.\nRun: npx playwright install chromium");
      }

      const reports: string[] = [];

      try {
        for (const schema of schemas) {
          const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
          const page = await ctx.newPage();

          // Auto-dismiss confirm dialogs
          page.on("dialog", async (d: any) => {
            await d.accept();
          });

          // Track console errors
          let consoleErrs: string[] = [];
          page.on("console", (msg: any) => {
            if (msg.type() === "error") consoleErrs.push(msg.text());
          });

          const ssDir = path.resolve("data/screenshots", schema);
          await fs.mkdir(ssDir, { recursive: true });

          const visited = new Set<string>();
          const pageRows: string[] = [];
          const postRows: string[] = [];
          let errors = 0,
            warns = 0,
            oks = 0;

          // Wait for SPA content to render
          async function waitSPA() {
            await page
              .waitForFunction(
                () => {
                  const app = document.getElementById("app");
                  return app && !(app.textContent || "").includes("Chargement");
                },
                { timeout: 8000 },
              )
              .catch(() => {});
            await page.waitForTimeout(300);
          }

          // Screenshot filename from URL path
          function ssFile(p: string) {
            return `${p.replace(/^\//, "").replace(/[/?=&]/g, "_") || "index"}.png`;
          }

          // Crawl a page
          async function crawl(urlPath: string, depth: number) {
            const key = urlPath.replace(/\/$/, "") || `/${schema}`;
            if (visited.has(key) || depth > maxDepth) return;
            visited.add(key);

            consoleErrs = [];
            const t0 = Date.now();

            try {
              const resp = await page.goto(baseUrl + urlPath, {
                waitUntil: "networkidle",
                timeout: 10000,
              });
              await waitSPA();
              const ms = Date.now() - t0;
              const st = resp?.status() ?? 0;

              // Content checks
              const body = (await page.textContent("#app").catch(() => "")) || "";
              const empty = body.trim().length < 20;

              // Screenshot
              const file = ssFile(urlPath);
              await page.screenshot({ path: path.join(ssDir, file), fullPage: true });

              // Classify
              const errs = [...consoleErrs];
              let badge: string;
              if (st >= 400) {
                badge = "ERR";
                errors++;
              } else if (empty) {
                badge = "WARN";
                warns++;
              } else if (errs.length) {
                badge = "WARN";
                warns++;
              } else if (ms > 500) {
                badge = "SLOW";
                warns++;
              } else {
                badge = "OK";
                oks++;
              }

              pageRows.push(
                `| ${badge} | \`${urlPath}\` | ${st} | ${ms}ms | ${errs.length ? `${errs.length} err` : "clean"} | ${file} |`,
              );

              // POST testing on pages at depth <= 1
              if (testPost && depth <= 1) {
                await testPosts(urlPath);
              }

              // Collect links for deeper crawl
              if (depth < maxDepth) {
                const links: string[] = await page
                  .$$eval(`a[href^="/${schema}/"], a[href^="/${schema}?"]`, (els: any[]) => [
                    ...new Set(els.map((a: any) => a.getAttribute("href")).filter(Boolean)),
                  ])
                  .catch(() => []);

                for (const link of links) {
                  if (link && !link.includes("#")) await crawl(link, depth + 1);
                }
              }
            } catch (err: any) {
              errors++;
              pageRows.push(`| ERR | \`${urlPath}\` | — | — | ${err.message?.slice(0, 60)} | — |`);
            }
          }

          // Test POST actions on current page
          async function testPosts(currentPath: string) {
            // Reveal hidden forms inside <details>
            await page
              .$$eval("details", (els: any[]) => {
                for (const d of els) d.open = true;
              })
              .catch(() => {});
            await page.waitForTimeout(200);

            // --- Forms with data-rpc ---
            const formRpcs: string[] = await page
              .$$eval("form[data-rpc]", (els: any[]) => els.map((f: any) => f.dataset.rpc))
              .catch(() => []);

            for (const rpc of formRpcs) {
              try {
                const form = await page.$(`form[data-rpc="${rpc}"]`);
                if (!form) continue;

                // Fill visible inputs with test data
                for (const input of await form.$$('input:not([type="hidden"]):not([type="checkbox"]), textarea')) {
                  const type = (await input.getAttribute("type")) || "text";
                  await input.fill(
                    type === "email"
                      ? "test@visual.test"
                      : type === "tel"
                        ? "0600000000"
                        : type === "number"
                          ? "1"
                          : "Test visual",
                  );
                }

                // Click submit + capture response
                const btn = await form.$('button[type="submit"], button:not([type])');
                if (!btn) continue;

                const [resp] = await Promise.all([
                  page
                    .waitForResponse((r: any) => r.url().includes("/rpc/") && r.request().method() === "POST", {
                      timeout: 5000,
                    })
                    .catch(() => null),
                  btn.click(),
                ]);

                if (resp) {
                  const st = (resp as any).status();
                  if (st >= 400) {
                    errors++;
                    const body = await (resp as any).json().catch(() => ({}) as any);
                    postRows.push(
                      `| ERR | \`${currentPath}\` | form | \`${rpc}\` | ${st} | ${body?.code || body?.message || "error"} |`,
                    );
                  } else {
                    oks++;
                    postRows.push(`| OK | \`${currentPath}\` | form | \`${rpc}\` | ${st} | success |`);
                  }
                } else {
                  warns++;
                  postRows.push(`| WARN | \`${currentPath}\` | form | \`${rpc}\` | — | timeout |`);
                }

                // Re-navigate for next test
                await page.goto(baseUrl + currentPath, { waitUntil: "networkidle", timeout: 10000 });
                await waitSPA();
                await page
                  .$$eval("details", (els: any[]) => {
                    for (const d of els) d.open = true;
                  })
                  .catch(() => {});
                await page.waitForTimeout(200);
              } catch (err: any) {
                warns++;
                postRows.push(`| WARN | \`${currentPath}\` | form | \`${rpc}\` | — | ${err.message?.slice(0, 50)} |`);
              }
            }

            // --- Buttons with data-rpc (non-confirm, not inside forms) ---
            const btnRpcs: string[] = await page
              .$$eval("button[data-rpc]:not([data-confirm])", (els: any[]) =>
                els.filter((b: any) => !b.closest("form[data-rpc]")).map((b: any) => b.dataset.rpc),
              )
              .catch(() => []);

            for (const rpc of [...new Set(btnRpcs)]) {
              try {
                const btn = await page.$(`button[data-rpc="${rpc}"]:not([data-confirm])`);
                if (!btn) continue;

                const [resp] = await Promise.all([
                  page
                    .waitForResponse((r: any) => r.url().includes("/rpc/") && r.request().method() === "POST", {
                      timeout: 5000,
                    })
                    .catch(() => null),
                  btn.click(),
                ]);

                if (resp) {
                  const st = (resp as any).status();
                  if (st >= 400) {
                    errors++;
                    postRows.push(`| ERR | \`${currentPath}\` | button | \`${rpc}\` | ${st} | error |`);
                  } else {
                    oks++;
                    postRows.push(`| OK | \`${currentPath}\` | button | \`${rpc}\` | ${st} | success |`);
                  }
                } else {
                  warns++;
                  postRows.push(`| WARN | \`${currentPath}\` | button | \`${rpc}\` | — | timeout |`);
                }

                // Re-navigate
                await page.goto(baseUrl + currentPath, { waitUntil: "networkidle", timeout: 10000 });
                await waitSPA();
              } catch (err: any) {
                warns++;
                postRows.push(`| WARN | \`${currentPath}\` | button | \`${rpc}\` | — | ${err.message?.slice(0, 50)} |`);
              }
            }
          }

          // Start crawl from index
          await crawl(`/${schema}/`, 0);

          // Build LMNAV report
          const parts: string[] = [];
          parts.push(`# Visual Test: ${schema}`);
          parts.push(`completeness: full`);
          parts.push(`pages: ${visited.size} crawled`);
          parts.push(`screenshots: data/screenshots/${schema}/`);
          parts.push(`bilan: ${errors ? `${errors} error(s) ` : ""}${warns ? `${warns} warning(s) ` : ""}${oks} ok`);
          parts.push("");
          parts.push("## Pages");
          parts.push("| Status | Path | HTTP | Rendu | Console | Screenshot |");
          parts.push("|--------|------|------|-------|---------|------------|");
          parts.push(...pageRows);

          if (postRows.length > 0) {
            parts.push("");
            parts.push("## POST Actions");
            parts.push("| Status | Page | Type | RPC | HTTP | Detail |");
            parts.push("|--------|------|------|-----|------|--------|");
            parts.push(...postRows);
          } else if (testPost) {
            parts.push("");
            parts.push("## POST Actions");
            parts.push("no forms or buttons found on crawled pages");
          }

          reports.push(parts.join("\n"));
          await ctx.close();
        }
      } finally {
        await browser.close();
      }

      return text(reports.join("\n\n---\n\n"));
    },
  };
}
