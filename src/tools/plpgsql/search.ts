import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { PlUri } from "../../uri.js";

const SEARCH_LIMIT = 20;

export function createSearchTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_search",
      description:
        "Find database objects by name or content. Searches functions, tables, triggers, and types.\n" +
        "Returns matching objects with navigable URIs.\n" +
        "name: SQL LIKE pattern (% = wildcard). content: regex search in function bodies.\n" +
        "Results capped at 20 per object type. Narrow with schema or kind if truncated.",
      schema: z.object({
        name: z.string().optional().describe("Name pattern. Ex: %transfer%, order%"),
        content: z.string().optional().describe("Regex in function bodies. Ex: INSERT INTO orders"),
        schema: z.string().optional().describe("Limit to schema (default: all)"),
        kind: z.enum(["all", "function", "table", "trigger", "type"]).optional().describe("Object type (default: all)"),
      }),
    },
    handler: async (args, _extra) => {
      const name = args.name as string | undefined;
      const content = args.content as string | undefined;
      const schema = args.schema as string | undefined;
      const kind = args.kind as string | undefined;

      if (!name && !content) return text("✗ provide name and/or content");

      return withClient(async (client) => {
        const searchKind = kind ?? "all";
        const sections: string[] = [];

        function schemaConditions(nsAlias: string): { conditions: string[]; params: string[]; nextIdx: number } {
          const conditions: string[] = [];
          const params: string[] = [];
          let pi = 1;
          if (schema) {
            conditions.push(`${nsAlias}.nspname = $${pi++}`);
            params.push(schema);
          } else {
            conditions.push(`${nsAlias}.nspname NOT LIKE 'pg_%'`);
            conditions.push(`${nsAlias}.nspname != 'information_schema'`);
          }
          return { conditions, params, nextIdx: pi };
        }

        function formatCount(shown: number, hasMore: boolean): string {
          return hasMore ? `${shown}+` : `${shown}`;
        }

        // --- Functions ---
        if (searchKind === "all" || searchKind === "function") {
          const { conditions, params, nextIdx } = schemaConditions("n");
          let pi = nextIdx;
          conditions.push("l.lanname = 'plpgsql'");

          if (name) { conditions.push(`p.proname LIKE $${pi++}`); params.push(name); }
          if (content) { conditions.push(`p.prosrc ~ $${pi++}`); params.push(content); }

          const contentIdx = content ? pi - 1 : 0;
          const { rows } = await client.query<{
            schema_name: string; obj_name: string; signature: string; match_lines: string | null;
          }>(`
            SELECT n.nspname AS schema_name, p.proname AS obj_name,
              p.proname || '(' || COALESCE(pg_get_function_arguments(p.oid), '') || ') -> ' || pg_get_function_result(p.oid) AS signature,
              ${content ? `(
                SELECT string_agg(line_num || '| ' || line, E'\\n' ORDER BY line_num)
                FROM unnest(string_to_array(p.prosrc, E'\\n')) WITH ORDINALITY AS lines(line, line_num)
                WHERE line ~ $${contentIdx}
              )` : "NULL"} AS match_lines
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            JOIN pg_language l ON l.oid = p.prolang
            WHERE ${conditions.join(" AND ")}
            ORDER BY n.nspname, p.proname
            LIMIT ${SEARCH_LIMIT + 1}
          `, params);

          if (rows.length > 0) {
            const hasMore = rows.length > SEARCH_LIMIT;
            const display = hasMore ? rows.slice(0, SEARCH_LIMIT) : rows;
            const lines = display.map((r) => {
              let line = `  ${r.signature}  ${PlUri.fn(r.schema_name, r.obj_name)}`;
              if (r.match_lines) {
                line += "\n" + r.match_lines.split("\n").map((l) => `      ${l.trim()}`).join("\n");
              }
              return line;
            });
            sections.push(`functions (${formatCount(display.length, hasMore)}):\n${lines.join("\n")}`);
          }
        }

        // --- Tables ---
        if ((searchKind === "all" || searchKind === "table") && !content) {
          const { conditions, params, nextIdx } = schemaConditions("n");
          let pi = nextIdx;
          conditions.push("c.relkind = 'r'");
          if (name) { conditions.push(`c.relname LIKE $${pi++}`); params.push(name); }

          const { rows } = await client.query<{ schema_name: string; obj_name: string }>(`
            SELECT n.nspname AS schema_name, c.relname AS obj_name
            FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE ${conditions.join(" AND ")}
            ORDER BY n.nspname, c.relname
            LIMIT ${SEARCH_LIMIT + 1}
          `, params);

          if (rows.length > 0) {
            const hasMore = rows.length > SEARCH_LIMIT;
            const display = hasMore ? rows.slice(0, SEARCH_LIMIT) : rows;
            const lines = display.map((r) => `  ${r.obj_name}  ${PlUri.table(r.schema_name, r.obj_name)}`);
            sections.push(`tables (${formatCount(display.length, hasMore)}):\n${lines.join("\n")}`);
          }
        }

        // --- Triggers ---
        if ((searchKind === "all" || searchKind === "trigger") && !content) {
          const { conditions, params, nextIdx } = schemaConditions("n");
          let pi = nextIdx;
          conditions.push("NOT t.tgisinternal");
          if (name) { conditions.push(`t.tgname LIKE $${pi++}`); params.push(name); }

          const { rows } = await client.query<{ schema_name: string; obj_name: string; on_table: string }>(`
            SELECT DISTINCT n.nspname AS schema_name, t.tgname AS obj_name, c.relname AS on_table
            FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE ${conditions.join(" AND ")}
            ORDER BY n.nspname, t.tgname
            LIMIT ${SEARCH_LIMIT + 1}
          `, params);

          if (rows.length > 0) {
            const hasMore = rows.length > SEARCH_LIMIT;
            const display = hasMore ? rows.slice(0, SEARCH_LIMIT) : rows;
            const lines = display.map((r) => `  ${r.obj_name} ON ${r.on_table}  ${PlUri.trigger(r.schema_name, r.obj_name)}`);
            sections.push(`triggers (${formatCount(display.length, hasMore)}):\n${lines.join("\n")}`);
          }
        }

        // --- Types ---
        if ((searchKind === "all" || searchKind === "type") && !content) {
          const { conditions, params, nextIdx } = schemaConditions("n");
          let pi = nextIdx;
          conditions.push("t.typtype IN ('c', 'e')");
          conditions.push("t.typname NOT LIKE '\\_%'");
          if (name) { conditions.push(`t.typname LIKE $${pi++}`); params.push(name); }

          const { rows } = await client.query<{ schema_name: string; obj_name: string; typtype: string }>(`
            SELECT n.nspname AS schema_name, t.typname AS obj_name, t.typtype
            FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE ${conditions.join(" AND ")}
            ORDER BY n.nspname, t.typname
            LIMIT ${SEARCH_LIMIT + 1}
          `, params);

          if (rows.length > 0) {
            const hasMore = rows.length > SEARCH_LIMIT;
            const display = hasMore ? rows.slice(0, SEARCH_LIMIT) : rows;
            const lines = display.map((r) => {
              const k = r.typtype === "e" ? "enum" : "composite";
              return `  ${r.obj_name} (${k})  ${PlUri.type(r.schema_name, r.obj_name)}`;
            });
            sections.push(`types (${formatCount(display.length, hasMore)}):\n${lines.join("\n")}`);
          }
        }

        if (sections.length === 0) return text("completeness: full\n\nno matches");

        const anyTruncated = sections.some((s) => s.includes("+):"));
        const header = `completeness: ${anyTruncated ? "partial" : "full"}`;
        const body = sections.join("\n\n");
        const next: string[] = [];
        if (anyTruncated) next.push("narrow with schema: or kind: to see all results");

        const parts = [header, "", body];
        if (next.length > 0) {
          parts.push("", "next:");
          for (const n of next) parts.push(`  - ${n}`);
        }
        return text(parts.join("\n"));
      });
    },
  };
}
