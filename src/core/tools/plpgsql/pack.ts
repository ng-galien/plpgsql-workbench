import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { ensureParserModule, extractFuncDeps } from "./deps.js";
import fs from "fs/promises";
import path from "path";

interface FuncRow {
  schema: string;
  name: string;
  lang: string;
  ddl: string;
  oid: string;
  description: string | null;
  ident: string;
}

async function querySchemaFunctions(
  client: DbClient,
  schemas: string[],
): Promise<FuncRow[]> {
  const { rows } = await client.query<FuncRow>(
    `SELECT n.nspname AS schema, p.proname AS name, l.lanname AS lang,
            pg_get_functiondef(p.oid) AS ddl, p.oid::text,
            obj_description(p.oid, 'pg_proc') AS description,
            p.oid::regprocedure::text AS ident
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_language l ON l.oid = p.prolang
     WHERE n.nspname = ANY($1)
       AND l.lanname IN ('sql', 'plpgsql')
       AND NOT EXISTS (
         SELECT 1 FROM pg_depend d
         JOIN pg_extension e ON e.oid = d.refobjid
         WHERE d.objid = p.oid AND d.deptype = 'e'
       )
     ORDER BY p.proname, p.oid`,
    [schemas],
  );
  return rows;
}

// ── Topological sort ─────────────────────────────────────────────

interface Edge { caller: string; callee: string }

function topoSort(fns: FuncRow[], edges: Edge[]): FuncRow[] {
  const key = (f: FuncRow) => `${f.schema}.${f.name}.${f.oid}`;
  const keySet = new Set(fns.map(key));

  // Build a lookup: "schema.name" → oid keys (may have overloads)
  const nameToKeys = new Map<string, string[]>();
  const byKey = new Map<string, FuncRow>();
  for (const f of fns) {
    const k = key(f);
    byKey.set(k, f);
    const qname = `${f.schema}.${f.name}`;
    const arr = nameToKeys.get(qname) ?? [];
    arr.push(k);
    nameToKeys.set(qname, arr);
  }

  // Edges use oid-based keys
  const inDegree = new Map<string, number>();
  const graph = new Map<string, string[]>(); // callee-key → [caller-keys]
  for (const f of fns) {
    const k = key(f);
    inDegree.set(k, 0);
    graph.set(k, []);
  }

  for (const e of edges) {
    // callee name → all matching oid keys
    const calleeKeys = nameToKeys.get(e.callee) ?? [];
    const callerKeys = nameToKeys.get(e.caller) ?? [];
    for (const ck of calleeKeys) {
      for (const rk of callerKeys) {
        if (ck !== rk && keySet.has(ck) && keySet.has(rk)) {
          inDegree.set(rk, (inDegree.get(rk) ?? 0) + 1);
          graph.get(ck)!.push(rk);
        }
      }
    }
  }

  // BFS with stable alphabetical ordering
  const queue: string[] = [];
  for (const [k, deg] of inDegree) {
    if (deg === 0) queue.push(k);
  }
  queue.sort((a, b) => byKey.get(a)!.name.localeCompare(byKey.get(b)!.name));

  const result: FuncRow[] = [];
  while (queue.length > 0) {
    const k = queue.shift()!;
    result.push(byKey.get(k)!);
    for (const caller of graph.get(k) ?? []) {
      const deg = (inDegree.get(caller) ?? 1) - 1;
      inDegree.set(caller, deg);
      if (deg === 0) {
        const callerName = byKey.get(caller)!.name;
        const idx = queue.findIndex((q) => byKey.get(q)!.name.localeCompare(callerName) > 0);
        queue.splice(idx === -1 ? queue.length : idx, 0, caller);
      }
    }
  }

  // Append remaining (circular deps) in original order
  if (result.length < fns.length) {
    const seen = new Set(result.map(key));
    for (const f of fns) {
      if (!seen.has(key(f))) result.push(f);
    }
  }
  return result;
}

// ── Tool ─────────────────────────────────────────────────────────

export function createPackTool({ withClient, moduleRegistry }: {
  withClient: WithClient;
  moduleRegistry: Promise<import("../../pgm/registry.js").ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_pack",
      description:
        "Export schemas into a single consolidated SQL init file.\n" +
        "Includes CREATE SCHEMA + all functions (dependency-sorted via AST) + GRANT.\n" +
        "Output path is auto-resolved from module registry (schema → module → file).",
      schema: z.object({
        schemas: z.string().describe("Comma-separated schema names. Ex: cad,cad_ut"),
        role: z.string().optional().describe("Role for GRANT EXECUTE (default: anon)"),
      }),
    },
    handler: async (args) => {
      const schemas = (args.schemas as string).split(",").map((s) => s.trim()).filter(Boolean);
      const role = (args.role as string) ?? "anon";

      if (schemas.length === 0) return text("problem: no schemas specified");

      const registry = await moduleRegistry;
      const mapping = registry.resolve(schemas);
      if (!mapping) {
        return text(
          `problem: no module owns schemas [${schemas.join(", ")}]\n` +
          `where: pg_pack\n` +
          `fix_hint: check modules/*/module.json schemas field`,
        );
      }
      if (!mapping.functionsFile) {
        return text(
          `problem: module "${mapping.module}" has no functions SQL file in module.json\n` +
          `where: pg_pack\n` +
          `fix_hint: add a "build/<schema>.func.sql" entry to module.json sql field`,
        );
      }

      return withClient(async (client) => {
        await ensureParserModule();

        const allFns = await querySchemaFunctions(client, schemas);

        // Extract deps via AST for each function (single pass, cached)
        const edges: Edge[] = [];
        const knownNames = new Set(allFns.map((f) => `${f.schema}.${f.name}`));
        const boundaryViolations: { caller: string; callee: string }[] = [];

        for (const fn of allFns) {
          const calls = await extractFuncDeps(fn);
          const callerName = `${fn.schema}.${fn.name}`;
          for (const callee of calls) {
            if (knownNames.has(callee)) {
              edges.push({ caller: callerName, callee });
            }
            // Detect cross-module calls to _* internal functions
            const [calleeSchema, calleeFnName] = callee.split(".");
            if (calleeFnName?.startsWith("_") && !schemas.includes(calleeSchema)) {
              boundaryViolations.push({ caller: callerName, callee });
            }
          }
        }

        const sorted = topoSort(allFns, edges);

        let totalFunctions = 0;
        const schemaCounts: Record<string, number> = {};

        // Write one .func.sql file PER schema
        for (const schema of schemas) {
          const fns = sorted.filter((f) => f.schema === schema);
          const sections: string[] = [];

          sections.push(`-- Auto-generated by pg_pack (${schema})`);
          sections.push(`-- ${new Date().toISOString().slice(0, 10)}`);
          sections.push("");
          sections.push(`CREATE SCHEMA IF NOT EXISTS ${schema};`);
          sections.push("");

          if (fns.length === 0) {
            sections.push(`-- (no functions)`);
          } else {
            // Fetch triggers for this schema (to attach after their trigger functions)
            const { rows: triggers } = await client.query(
              `SELECT t.tgname, c.relname, n.nspname AS table_schema,
                      pg_get_triggerdef(t.oid) AS triggerdef,
                      p.proname AS func_name, pn.nspname AS func_schema
               FROM pg_trigger t
               JOIN pg_class c ON c.oid = t.tgrelid
               JOIN pg_namespace n ON n.oid = c.relnamespace
               JOIN pg_proc p ON p.oid = t.tgfoid
               JOIN pg_namespace pn ON pn.oid = p.pronamespace
               WHERE pn.nspname = $1 AND NOT t.tgisinternal`,
              [schema],
            );
            const triggersByFunc = new Map<string, string[]>();
            for (const trig of triggers) {
              const key = `${trig.func_schema}.${trig.func_name}`;
              if (!triggersByFunc.has(key)) triggersByFunc.set(key, []);
              triggersByFunc.get(key)!.push(
                `DROP TRIGGER IF EXISTS ${trig.tgname} ON ${trig.table_schema}.${trig.relname};\n${trig.triggerdef};`,
              );
            }

            for (const fn of fns) {
              const ddl = fn.ddl.trimEnd();
              sections.push(ddl.endsWith(";") ? ddl : ddl + ";");
              if (fn.description) {
                const escaped = fn.description.replace(/'/g, "''");
                sections.push(`COMMENT ON FUNCTION ${fn.ident} IS '${escaped}';`);
              }
              // Attach triggers that use this function
              const fnKey = `${fn.schema}.${fn.name}`;
              const trigs = triggersByFunc.get(fnKey);
              if (trigs) {
                for (const t of trigs) sections.push(t);
              }
              sections.push("");
            }
            totalFunctions += fns.length;
          }

          sections.push(`GRANT USAGE ON SCHEMA ${schema} TO ${role};`);
          sections.push(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${schema} TO ${role};`);
          sections.push(`GRANT SELECT ON ALL TABLES IN SCHEMA ${schema} TO ${role};`);
          sections.push("");

          // Output path: build/{schema}.func.sql
          const schemaFile = path.join(mapping.modulePath, "build", `${schema}.func.sql`);
          await fs.mkdir(path.dirname(schemaFile), { recursive: true });
          await fs.writeFile(schemaFile, sections.join("\n"), "utf-8");
          schemaCounts[schema] = fns.length;
        }

        // --- Coherence check: build/ vs src/ ---
        const srcDir = path.join(mapping.modulePath, "src");
        const missing: string[] = [];   // in DB but not in src/
        const extra: string[] = [];     // in src/ but not in DB

        const dbFuncs = new Map<string, Set<string>>(); // schema → Set<name>
        for (const fn of sorted) {
          if (!dbFuncs.has(fn.schema)) dbFuncs.set(fn.schema, new Set());
          dbFuncs.get(fn.schema)!.add(fn.name);
        }

        // Check each packed function has a src/ (or qa/) file
        for (const [schema, names] of dbFuncs) {
          const baseDir = schema.endsWith("_qa") ? path.join(mapping.modulePath, "qa") : srcDir;
          for (const name of names) {
            const srcFile = path.join(baseDir, schema, `${name}.sql`);
            try { await fs.access(srcFile); }
            catch { missing.push(`${schema}/${name}.sql`); }
          }
        }

        // Check for extra files in src/ (or qa/) not in DB
        for (const schema of schemas) {
          const baseDir = schema.endsWith("_qa") ? path.join(mapping.modulePath, "qa") : srcDir;
          const schemaDir = path.join(baseDir, schema);
          try {
            const files = await fs.readdir(schemaDir);
            const dbNames = dbFuncs.get(schema) ?? new Set();
            for (const f of files) {
              if (!f.endsWith(".sql")) continue;
              const funcName = f.replace(/(_\d+)?\.sql$/, "");
              if (!dbNames.has(funcName)) {
                extra.push(`${schema}/${f}`);
              }
            }
          } catch { /* src/schema/ doesn't exist yet */ }
        }

        const parts: string[] = [];
        const fileList = schemas.map(s => `build/${s}.func.sql`).join(", ");
        parts.push(`packed ${totalFunctions} functions from ${schemas.length} schema(s) -> ${fileList}`);
        parts.push(`deps: ${edges.length} edges resolved via AST`);
        parts.push("");
        for (const s of schemas) {
          const count = sorted.filter((f) => f.schema === s).length;
          parts.push(`  ${s}: ${count} functions`);
        }

        if (boundaryViolations.length > 0) {
          parts.push("");
          parts.push("boundaries: VIOLATION");
          parts.push("  cross-module calls to internal (_prefix) functions:");
          for (const v of boundaryViolations) {
            parts.push(`    - ${v.caller} -> ${v.callee}`);
          }
        } else {
          parts.push("");
          parts.push("boundaries: ok");
        }

        if (missing.length === 0 && extra.length === 0) {
          parts.push("");
          parts.push("coherence: ok (build/ and src/ in sync)");
        } else {
          parts.push("");
          parts.push("coherence: MISMATCH");
          if (missing.length > 0) {
            parts.push(`  missing from src/ (run pg_func_save):`);
            for (const m of missing) parts.push(`    - ${m}`);
          }
          if (extra.length > 0) {
            parts.push(`  extra in src/ (not in DB — deleted function?):`);
            for (const e of extra) parts.push(`    - ${e}`);
          }
        }

        parts.push("");
        parts.push(`completeness: full`);
        return text(parts.join("\n"));
      });
    },
  };
}
