import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import fs from "fs/promises";
import path from "path";

function resolveOutPath(outPath: string): string {
  if (path.isAbsolute(outPath)) return outPath;
  return path.resolve(process.cwd(), outPath);
}

interface FunctionEntry {
  oid: string;
  schema: string;
  name: string;
  ddl: string;
}

async function queryFunctions(
  client: DbClient,
  schema?: string,
  fnName?: string,
): Promise<FunctionEntry[]> {
  let where = "l.lanname IN ('plpgsql', 'sql') AND NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_extension e ON e.oid = d.refobjid WHERE d.objid = p.oid AND d.deptype = 'e')";
  const params: string[] = [];

  if (schema) {
    params.push(schema);
    where += ` AND n.nspname = $${params.length}`;
  } else {
    where += ` AND n.nspname NOT IN ('pg_catalog', 'information_schema')`;
  }

  if (fnName) {
    params.push(fnName);
    where += ` AND p.proname = $${params.length}`;
  }

  const { rows } = await client.query<FunctionEntry>(
    `SELECT p.oid::text, n.nspname AS schema, p.proname AS name,
            pg_get_functiondef(p.oid) AS ddl
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_language l ON l.oid = p.prolang
     WHERE ${where}
     ORDER BY n.nspname, p.proname, p.oid`,
    params,
  );
  return rows;
}

async function dumpFunctions(
  client: DbClient,
  outDir: string,
  schema?: string,
  fnName?: string,
): Promise<string> {
  const functions = await queryFunctions(client, schema, fnName);

  if (functions.length === 0) {
    return "no functions found";
  }

  const counts = new Map<string, number>();
  for (const fn of functions) {
    const key = `${fn.schema}/${fn.name}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  const idx = new Map<string, number>();
  const written: string[] = [];

  for (const fn of functions) {
    const schemaDir = path.join(outDir, fn.schema);
    await fs.mkdir(schemaDir, { recursive: true });

    const key = `${fn.schema}/${fn.name}`;
    let fileName: string;
    if ((counts.get(key) ?? 1) > 1) {
      const i = (idx.get(key) ?? 0) + 1;
      idx.set(key, i);
      fileName = `${fn.name}_${i}.sql`;
    } else {
      fileName = `${fn.name}.sql`;
    }

    const filePath = path.join(schemaDir, fileName);
    const content = fn.ddl.trimEnd().endsWith(";") ? fn.ddl : fn.ddl.trimEnd() + ";\n";
    await fs.writeFile(filePath, content, "utf-8");
    written.push(`${fn.schema}/${fileName}`);
  }

  const parts: string[] = [];
  parts.push(`dumped ${written.length} function${written.length !== 1 ? "s" : ""} to ${outDir}`);
  parts.push(`completeness: full`);
  parts.push("");
  for (const f of written) {
    parts.push(`  ${f}`);
  }
  return parts.join("\n");
}

export function createDumpTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_dump",
      description:
        "Export PL/pgSQL and SQL functions to SQL files on disk for version control.\n" +
        "Creates one .sql file per function with full CREATE OR REPLACE DDL.\n" +
        "Structure: {path}/{schema}/{function_name}.sql",
      schema: z.object({
        target: z
          .string()
          .optional()
          .describe(
            "plpgsql:// URI scope. Omit for all schemas, plpgsql://schema for one schema, plpgsql://schema/function/name for one function",
          ),
        path: z.string().describe("Output directory (absolute or relative to server CWD)"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.target as string | undefined;
      const outPath = args.path as string;

      return withClient(async (client) => {
        let schema: string | undefined;
        let fnName: string | undefined;

        if (target) {
          const fnMatch = target.match(/^plpgsql:\/\/(\w+)\/function\/(\w+)$/);
          if (fnMatch) {
            schema = fnMatch[1];
            fnName = fnMatch[2];
          } else {
            const schemaMatch = target.match(/^plpgsql:\/\/(\w+)\/?$/);
            if (schemaMatch) {
              schema = schemaMatch[1];
            } else {
              return text(`problem: invalid target: ${target}\nwhere: pg_dump\nfix_hint: expected plpgsql://schema or plpgsql://schema/function/name`);
            }
          }
        }

        const result = await dumpFunctions(client, resolveOutPath(outPath), schema, fnName);
        return text(result);
      });
    },
  };
}
