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
        role: z.string().optional().describe("Role for GRANT EXECUTE (default: web_anon)"),
      }),
    },
    handler: async (args) => {
      const schemas = (args.schemas as string).split(",").map((s) => s.trim()).filter(Boolean);
      const role = (args.role as string) ?? "web_anon";

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
          `fix_hint: add a "sql/functions.sql" entry to module.json sql field`,
        );
      }

      const resolved = path.join(mapping.modulePath, mapping.functionsFile);

      return withClient(async (client) => {
        await ensureParserModule();

        const allFns = await querySchemaFunctions(client, schemas);

        // Extract deps via AST for each function
        const edges: Edge[] = [];
        const knownNames = new Set(allFns.map((f) => `${f.schema}.${f.name}`));

        for (const fn of allFns) {
          const calls = await extractFuncDeps(fn);
          for (const callee of calls) {
            if (knownNames.has(callee)) {
              edges.push({ caller: `${fn.schema}.${fn.name}`, callee });
            }
          }
        }

        const sorted = topoSort(allFns, edges);

        const sections: string[] = [];
        let totalFunctions = 0;

        for (const schema of schemas) {
          const fns = sorted.filter((f) => f.schema === schema);

          sections.push(`-- Schema: ${schema}`);
          sections.push(`CREATE SCHEMA IF NOT EXISTS ${schema};`);
          sections.push("");

          if (fns.length === 0) {
            sections.push(`-- (no functions)`);
          } else {
            for (const fn of fns) {
              const ddl = fn.ddl.trimEnd();
              sections.push(ddl.endsWith(";") ? ddl : ddl + ";");
              if (fn.description) {
                const escaped = fn.description.replace(/'/g, "''");
                sections.push(`COMMENT ON FUNCTION ${fn.ident} IS '${escaped}';`);
              }
              sections.push("");
            }
            totalFunctions += fns.length;
          }

          sections.push(`GRANT USAGE ON SCHEMA ${schema} TO ${role};`);
          sections.push(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${schema} TO ${role};`);
          sections.push("");
        }

        const content = `-- Auto-generated by pg_pack (${schemas.join(", ")})\n-- ${new Date().toISOString().slice(0, 10)}\n\n${sections.join("\n")}`;

        await fs.mkdir(path.dirname(resolved), { recursive: true });
        await fs.writeFile(resolved, content, "utf-8");

        const parts: string[] = [];
        parts.push(`packed ${totalFunctions} functions from ${schemas.length} schema(s) -> ${mapping.module}/${mapping.functionsFile}`);
        parts.push(`deps: ${edges.length} edges resolved via AST`);
        parts.push(`completeness: full`);
        parts.push("");
        for (const s of schemas) {
          const count = sorted.filter((f) => f.schema === s).length;
          parts.push(`  ${s}: ${count} functions`);
        }
        return text(parts.join("\n"));
      });
    },
  };
}
