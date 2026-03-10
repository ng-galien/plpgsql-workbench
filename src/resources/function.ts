import type { DbClient } from "../connection.js";
import { PlUri } from "../uri.js";

export interface FunctionDetail {
  name: string;
  schema: string;
  args: { name: string; type: string }[];
  return_type: string;
  description: string | null;
  variables: { name: string; type: string }[];
  body: string;
  calls: string[];
  callers: string[];
  tables_used: { name: string; mode: "R" | "W" | "RW" }[];
}

// --- Query ---

export async function queryFunctionDdl(client: DbClient, schema: string, name: string): Promise<string | null> {
  const { rows } = await client.query<{ def: string }>(`
    SELECT pg_get_functiondef(p.oid) AS def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname = $1 AND p.proname = $2 AND l.lanname IN ('sql', 'plpgsql')
    LIMIT 1
  `, [schema, name]);
  return rows.length > 0 ? rows[0].def : null;
}

export async function queryFunction(client: DbClient, schema: string, name: string): Promise<FunctionDetail | null> {
  const { rows } = await client.query<{
    oid: string;
    return_type: string;
    prosrc: string;
    args: string;
    description: string | null;
  }>(`
    SELECT
      p.oid::text,
      pg_get_function_result(p.oid) AS return_type,
      p.prosrc,
      COALESCE(pg_get_function_arguments(p.oid), '') AS args,
      obj_description(p.oid, 'pg_proc') AS description
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname = $1 AND p.proname = $2 AND l.lanname IN ('sql', 'plpgsql')
    LIMIT 1
  `, [schema, name]);

  if (rows.length === 0) return null;

  const row = rows[0];
  const body = row.prosrc.trim();
  const args = parseArgs(row.args);
  const variables = extractVariables(body);
  const calls = extractCalls(body);
  const callers = await findCallers(client, schema, name);
  const tables_used = await findTablesUsed(client, schema, body);

  return { name, schema, args, return_type: row.return_type, description: row.description, variables, body, calls, callers, tables_used };
}

// --- Format ---

export function formatFunction(fn: FunctionDetail): string {
  const argsStr = fn.args.map((a) => `${a.name} ${a.type}`).join(", ");
  const parts: string[] = [];

  parts.push(`${fn.schema}.${fn.name}(${argsStr}) -> ${fn.return_type}`);

  if (fn.description) {
    parts.push(`  doc: ${fn.description}`);
  }

  parts.push(fn.variables.length > 0
    ? `  vars: ${fn.variables.map((v) => `${v.name} ${v.type}`).join(", ")}`
    : `  vars: none`);
  parts.push(fn.calls.length > 0
    ? `  calls: ${fn.calls.join(", ")}`
    : `  calls: none`);
  parts.push(fn.callers.length > 0
    ? `  callers: ${fn.callers.join(", ")}`
    : `  callers: none`);
  parts.push(fn.tables_used.length > 0
    ? `  tables: ${fn.tables_used.map((t) => `${t.name}(${t.mode}) ${PlUri.table(fn.schema, t.name)}`).join(", ")}`
    : `  tables: none`);
  parts.push(`  body:`);
  const lines = fn.body.split("\n");
  const numWidth = String(lines.length).length;
  for (let i = 0; i < lines.length; i++) {
    parts.push(`    ${String(i + 1).padStart(numWidth)}| ${lines[i]}`);
  }

  return parts.join("\n");
}

// --- Helpers ---

function parseArgs(argsStr: string): { name: string; type: string }[] {
  if (!argsStr.trim()) return [];
  return argsStr.split(",").map((a) => {
    const parts = a.trim().split(/\s+/);
    if (parts.length >= 2) {
      return { name: parts[0], type: parts.slice(1).join(" ") };
    }
    return { name: "", type: parts[0] };
  });
}

function extractVariables(body: string): { name: string; type: string }[] {
  const vars: { name: string; type: string }[] = [];
  const declareMatch = body.match(/DECLARE\s+([\s\S]*?)BEGIN/i);
  if (!declareMatch) return vars;

  for (const line of declareMatch[1].split("\n")) {
    const m = line.trim().match(/^(\w+)\s+(.+?)\s*(?::=.*)?;$/i);
    if (m) {
      vars.push({ name: m[1], type: m[2].trim() });
    }
  }
  return vars;
}

function extractCalls(body: string): string[] {
  const calls = new Set<string>();
  const re = /(?:PERFORM|SELECT|:=)\s+(?:(\w+)\.)?(\w+)\s*\(/gi;
  let match;
  while ((match = re.exec(body)) !== null) {
    const fn = match[2];
    if (!SQL_BUILTINS.has(fn.toLowerCase())) {
      calls.add(match[1] ? `${match[1]}.${fn}` : fn);
    }
  }
  return Array.from(calls);
}

async function findCallers(client: DbClient, schema: string, name: string): Promise<string[]> {
  const { rows } = await client.query<{ caller: string }>(`
    SELECT n.nspname || '.' || p.proname AS caller
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.prosrc ~ $1
      AND NOT (n.nspname = $2 AND p.proname = $3)
    ORDER BY caller
  `, [`\\m${name}\\M`, schema, name]);
  return rows.map((r) => r.caller);
}

async function findTablesUsed(
  client: DbClient,
  schema: string,
  body: string,
): Promise<{ name: string; mode: "R" | "W" | "RW" }[]> {
  const { rows: tables } = await client.query<{ relname: string }>(`
    SELECT c.relname FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = $1 AND c.relkind = 'r'
  `, [schema]);

  const used: { name: string; mode: "R" | "W" | "RW" }[] = [];
  for (const t of tables) {
    const esc = t.relname.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const re = new RegExp(`\\b${esc}\\b`, "i");
    if (re.test(body)) {
      const hasWrite = new RegExp(`(INSERT\\s+INTO|UPDATE|DELETE\\s+FROM)\\s+.*\\b${esc}\\b`, "i").test(body);
      const hasRead = new RegExp(`(FROM|JOIN)\\s+.*\\b${esc}\\b`, "i").test(body);
      used.push({ name: t.relname, mode: hasWrite && hasRead ? "RW" : hasWrite ? "W" : "R" });
    }
  }
  return used;
}

const SQL_BUILTINS = new Set([
  "now", "coalesce", "nullif", "greatest", "least", "count", "sum", "avg",
  "min", "max", "array_agg", "string_agg", "row_to_json", "to_json",
  "to_jsonb", "jsonb_build_object", "jsonb_populate_record", "format",
  "concat", "length", "lower", "upper", "trim", "substr", "replace",
  "round", "ceil", "floor", "abs", "random", "gen_random_uuid",
  "nextval", "currval", "setval", "found",
]);
