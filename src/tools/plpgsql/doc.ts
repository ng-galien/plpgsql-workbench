import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { ensureParserModule, extractFuncDeps } from "./deps.js";

const HELPER_FNS = new Set([
  "esc", "path_segment", "pgv_money", "pgv_badge", "pgv_status", "pgv_tier", "pgv_nav",
  "h", "ok_response", "err_response", "list_response", "path_id",
]);

interface Dep {
  source_schema: string;
  source: string;
  dep_type: string;
  target_schema: string;
  target: string;
}

async function queryDeps(client: DbClient, schemas: string[]): Promise<Dep[]> {
  const hasPlpgsqlCheck = (await client.query(
    `SELECT 1 FROM pg_extension WHERE extname = 'plpgsql_check'`
  )).rowCount! > 0;

  const rows: Dep[] = [];
  for (const schema of schemas) {
    const fns = await client.query<{ oid: string; proname: string; lanname: string; ddl: string }>(
      `SELECT p.oid::text, p.proname, l.lanname, pg_get_functiondef(p.oid) AS ddl
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       JOIN pg_language l ON l.oid = p.prolang
       WHERE n.nspname = $1
         AND l.lanname IN ('sql', 'plpgsql')`,
      [schema]
    );

    // PL/pgSQL functions: use plpgsql_check if available (includes table deps)
    if (hasPlpgsqlCheck) {
      const plFns = fns.rows.filter(f => f.lanname === "plpgsql");
      await client.query("BEGIN");
      for (const fn of plFns) {
        try {
          await client.query("SAVEPOINT dep_check");
          const deps = await client.query(
            `SELECT type, schema, name FROM plpgsql_show_dependency_tb($1::oid)`,
            [fn.oid]
          );
          await client.query("RELEASE SAVEPOINT dep_check");
          for (const d of deps.rows) {
            rows.push({
              source_schema: schema,
              source: fn.proname,
              dep_type: d.type,
              target_schema: d.schema,
              target: d.name,
            });
          }
        } catch {
          await client.query("ROLLBACK TO SAVEPOINT dep_check").catch(() => {});
        }
      }
      await client.query("COMMIT");
    }

    // All functions (SQL + PL/pgSQL without plpgsql_check): use AST
    const astFns = hasPlpgsqlCheck
      ? fns.rows.filter(f => f.lanname === "sql")
      : fns.rows;

    await ensureParserModule();
    for (const fn of astFns) {
      const calls = await extractFuncDeps({
        schema, name: fn.proname, lang: fn.lanname, ddl: fn.ddl,
      });
      for (const callee of calls) {
        const [targetSchema, targetName] = callee.split(".");
        rows.push({
          source_schema: schema,
          source: fn.proname,
          dep_type: "FUNCTION",
          target_schema: targetSchema,
          target: targetName,
        });
      }
    }
  }
  return rows;
}

function buildGraph(deps: Dep[], schemas: string[], showHelpers: boolean, showTables: boolean, infraSet: Set<string>): string {
  const lines: string[] = ["graph LR"];
  const schemasSet = new Set(schemas);

  const isPage = (name: string) => name.startsWith("pgv_");
  const isRouter = (name: string) => name === "page";

  for (const schema of schemas) {
    const schemaFns = new Set(
      deps.filter(d => d.source_schema === schema).map(d => d.source)
    );
    const tables = new Set(
      deps.filter(d => d.source_schema === schema && d.dep_type === "RELATION" && d.target_schema === schema)
        .map(d => d.target)
    );

    const routers = [...schemaFns].filter(isRouter);
    const pages = [...schemaFns].filter(f => isPage(f) && (showHelpers || !HELPER_FNS.has(f)));
    const business = [...schemaFns].filter(f => !isRouter(f) && !isPage(f) && (showHelpers || !HELPER_FNS.has(f)));

    lines.push(`  subgraph ${schema}`);
    if (routers.length) {
      lines.push(`    subgraph ${schema}_router[Router]`);
      for (const f of routers) lines.push(`      ${schema}_${f}[${f}]`);
      lines.push(`    end`);
    }
    if (pages.length) {
      lines.push(`    subgraph ${schema}_pages[Pages]`);
      for (const f of pages) lines.push(`      ${schema}_${f}[${f}]`);
      lines.push(`    end`);
    }
    if (business.length) {
      lines.push(`    subgraph ${schema}_business[Business]`);
      for (const f of business) lines.push(`      ${schema}_${f}[${f}]`);
      lines.push(`    end`);
    }
    if (showTables && tables.size > 0) {
      lines.push(`    subgraph ${schema}_data[(Tables)]`);
      for (const t of tables) lines.push(`      ${schema}_${t}[("${t}")]`);
      lines.push(`    end`);
    }
    lines.push(`  end`);
  }

  for (const d of deps) {
    if (d.dep_type === "RELATION" && !showTables) continue;
    if (!showHelpers && HELPER_FNS.has(d.target)) continue;
    if (!showHelpers && HELPER_FNS.has(d.source)) continue;

    const sourceId = `${d.source_schema}_${d.source}`;
    const targetId = `${d.target_schema}_${d.target}`;
    const arrow = d.dep_type === "RELATION" ? "-.->" : "-->";

    if (d.source_schema !== d.target_schema && schemasSet.has(d.target_schema)) {
      const label = infraSet.has(d.target_schema) ? "INFRA" : "CROSS";
      lines.push(`  ${sourceId} ${arrow}|${label}| ${targetId}`);
    } else if (schemasSet.has(d.target_schema)) {
      lines.push(`  ${sourceId} ${arrow} ${targetId}`);
    }
  }

  return lines.join("\n");
}

export function createDocTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_doc",
      description: "Generate dependency graph (Mermaid) for a schema. Shows function calls, table access, and cross-schema boundary violations.",
      schema: z.object({
        schema: z.string().describe("Schema name, or comma-separated list. Ex: shop or clients,commandes"),
        infra: z.string().optional().describe("Infrastructure schemas (comma-separated). Cross-schema calls to these are informational, not violations. Ex: pgv,workbench"),
        tables: z.boolean().default(false).describe("Include table dependencies (default: false)"),
        helpers: z.boolean().default(false).describe("Include helper functions like esc, pgv_money (default: false)"),
      }),
    },
    handler: async (args, _extra) => {
      const schemaArg = args.schema as string;
      const infraArg = args.infra as string | undefined;
      const tables = (args.tables as boolean | undefined) ?? false;
      const helpers = (args.helpers as boolean | undefined) ?? false;
      const infraSet = new Set(infraArg?.split(",").map(s => s.trim()) ?? []);

      return withClient(async (client) => {
        const schemas = schemaArg.split(",").map(s => s.trim());

        const deps = await queryDeps(client, schemas);
        if (deps.length === 0) {
          return text(`No functions found in schema(s): ${schemas.join(", ")}`);
        }

        const mermaid = buildGraph(deps, schemas, helpers, tables, infraSet);

        const schemasSet = new Set(schemas);
        const crossSchema = deps.filter(
          d => d.source_schema !== d.target_schema
            && d.dep_type === "FUNCTION"
        );
        // _prefix convention: cross-schema calls to _* functions are always violations
        const privateViolations = crossSchema.filter(d => d.target.startsWith("_"));
        const publicCross = crossSchema.filter(d => !d.target.startsWith("_"));
        const infraCalls = publicCross.filter(d => infraSet.has(d.target_schema));
        const violations = publicCross.filter(d => !infraSet.has(d.target_schema) && schemasSet.has(d.target_schema));

        const parts: string[] = [];
        parts.push(`# Dependency Graph: ${schemas.join(", ")}`);
        parts.push(`completeness: full`);
        parts.push("");
        parts.push("```mermaid");
        parts.push(mermaid);
        parts.push("```");

        const fnCalls = deps.filter(d => d.dep_type === "FUNCTION" && (helpers || !HELPER_FNS.has(d.target)));
        const tblAccess = deps.filter(d => d.dep_type === "RELATION");
        const uniqueFns = new Set(deps.map(d => `${d.source_schema}.${d.source}`));

        parts.push("");
        parts.push("## Stats");
        parts.push(`- **${uniqueFns.size}** functions analyzed`);
        parts.push(`- **${fnCalls.length}** function calls`);
        parts.push(`- **${tblAccess.length}** table accesses`);

        if (privateViolations.length > 0) {
          parts.push("");
          parts.push("## Private Function Violations");
          parts.push("Cross-schema calls to internal (_prefix) functions:");
          for (const v of privateViolations) {
            parts.push(`- \`${v.source_schema}.${v.source}\` -> \`${v.target_schema}.${v.target}\` (internal)`);
          }
        }

        if (infraCalls.length > 0) {
          parts.push("");
          parts.push("## Cross-schema calls (infrastructure)");
          for (const v of infraCalls) {
            parts.push(`- \`${v.source_schema}.${v.source}\` -> \`${v.target_schema}.${v.target}\``);
          }
        }

        if (violations.length > 0) {
          parts.push("");
          parts.push("## Boundary Violations");
          parts.push("Cross-schema calls between business domains:");
          for (const v of violations) {
            parts.push(`- \`${v.source_schema}.${v.source}\` -> \`${v.target_schema}.${v.target}\``);
          }
        } else if (schemas.length > 1 && privateViolations.length === 0) {
          parts.push("");
          parts.push("## Boundaries");
          parts.push("No boundary violations detected.");
        }

        return text(parts.join("\n"));
      });
    },
  };
}
