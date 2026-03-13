import type { DbClient } from "../connection.js";
import { queryFunctionDdl } from "../resources/function.js";
import { extractCoveragePoints, type CoveragePoint } from "./visitor.js";
import crypto from "crypto";

export interface CoverageResult {
  runId: string;
  schema: string;
  name: string;
  points: CoveragePoint[];
  hit: Set<string>;
  totalPoints: number;
  coveredPoints: number;
  percentage: number;
}

const COV_PREFIX = "cov:";

/**
 * Extract the body (prosrc) from a pg_get_functiondef DDL.
 * Handles all dollar-quoting variants: $$, $function$, $body$, etc.
 */
function extractBody(ddl: string): { body: string; bodyStart: number } | null {
  // Find the AS keyword followed by a dollar-quoted tag
  // Dollar-quote tags: $ followed by optional identifier followed by $
  const asMatch = ddl.match(/AS\s+(\$(?:[a-zA-Z_][a-zA-Z0-9_]*)?\$)/i);
  if (!asMatch || asMatch.index === undefined) return null;
  const tag = asMatch[1]; // capture group = just the $tag$ part
  const tagStart = asMatch.index + asMatch[0].indexOf(tag);
  const openIdx = tagStart + tag.length;
  // Find closing tag — must be the same tag, search from after the opening
  const closeIdx = ddl.indexOf(tag, openIdx);
  if (closeIdx < 0) return null;
  return { body: ddl.slice(openIdx, closeIdx), bodyStart: openIdx };
}

/**
 * Inject coverage markers into the function body.
 * Handles three injection modes:
 * - "before": insert RAISE WARNING before the target line
 * - "inject_else": find END IF after searchAfter and inject ELSE RAISE WARNING
 * - "inject_after_loop": find END LOOP after searchAfter and inject RAISE WARNING after it
 */
function instrumentBody(body: string, points: CoveragePoint[]): string {
  const lines = body.split("\n");

  // 1. Handle "before" injections (bottom-up to preserve line numbers)
  const beforePoints = points.filter((p) => p.inject === "before");
  const byLine = new Map<number, CoveragePoint[]>();
  for (const p of beforePoints) {
    const arr = byLine.get(p.line) ?? [];
    arr.push(p);
    byLine.set(p.line, arr);
  }

  const sortedLines = [...byLine.keys()].sort((a, b) => b - a);
  for (const lineNo of sortedLines) {
    const idx = lineNo - 1;
    if (idx < 0 || idx >= lines.length) continue;
    const indent = lines[idx].match(/^(\s*)/)?.[1] ?? "  ";
    const markers = byLine.get(lineNo)!;
    const injected = markers.reverse().map(
      (p) => `${indent}RAISE WARNING '${COV_PREFIX}%', '${p.id}';`,
    );
    lines.splice(idx, 0, ...injected);
  }

  // 2. Handle "inject_else" — find END IF and insert ELSE clause before it
  //    Process bottom-up by searchAfter to avoid line shift issues
  const elsePoints = points.filter((p) => p.inject === "inject_else");
  elsePoints.sort((a, b) => (b.searchAfter ?? 0) - (a.searchAfter ?? 0));
  for (const p of elsePoints) {
    const afterLine = findOriginalLine(p.searchAfter ?? 0, beforePoints);
    const endIfIdx = findPattern(lines, afterLine, /^\s*END\s+IF\s*;/i);
    if (endIfIdx >= 0) {
      const indent = lines[endIfIdx].match(/^(\s*)/)?.[1] ?? "  ";
      lines.splice(endIfIdx, 0,
        `${indent}ELSE`,
        `${indent}  RAISE WARNING '${COV_PREFIX}%', '${p.id}';`,
      );
    }
  }

  // 3. Handle "inject_after_loop" — find END LOOP and insert marker after it
  const loopPoints = points.filter((p) => p.inject === "inject_after_loop");
  loopPoints.sort((a, b) => (b.searchAfter ?? 0) - (a.searchAfter ?? 0));
  for (const p of loopPoints) {
    const afterLine = findOriginalLine(p.searchAfter ?? 0, beforePoints);
    const endLoopIdx = findPattern(lines, afterLine, /^\s*END\s+LOOP\s*;/i);
    if (endLoopIdx >= 0) {
      const indent = lines[endLoopIdx].match(/^(\s*)/)?.[1] ?? "  ";
      lines.splice(endLoopIdx + 1, 0,
        `${indent}RAISE WARNING '${COV_PREFIX}%', '${p.id}';`,
      );
    }
  }

  return lines.join("\n");
}

/**
 * Account for lines inserted by "before" injections when mapping original line numbers
 * to current array indices. Returns the adjusted index.
 */
function findOriginalLine(originalLine: number, beforePoints: CoveragePoint[]): number {
  // Count how many "before" injections happened at or before this line
  let offset = 0;
  for (const p of beforePoints) {
    if (p.line <= originalLine) offset++;
  }
  return (originalLine - 1) + offset; // 1-indexed to 0-indexed + offset
}

/**
 * Search for a regex pattern in lines starting from startIdx.
 * For END IF / END LOOP, tracks nesting depth to find the correct match.
 */
function findPattern(lines: string[], startIdx: number, pattern: RegExp): number {
  const isEndIf = pattern.source.includes("END") && pattern.source.includes("IF");
  const isEndLoop = pattern.source.includes("END") && pattern.source.includes("LOOP");

  if (isEndIf) {
    // We start from inside the body of the IF whose END IF we seek.
    // Every nested IF/END IF pair cancels out. The target END IF
    // is the first one that drops depth below 0.
    let depth = 0;
    for (let i = startIdx; i < lines.length; i++) {
      if (/^\s*IF\b/i.test(lines[i])) depth++;
      if (/^\s*END\s+IF\s*;/i.test(lines[i])) {
        depth--;
        if (depth < 0) return i;
      }
    }
    return -1;
  }

  if (isEndLoop) {
    let depth = 0;
    for (let i = startIdx; i < lines.length; i++) {
      if (/^\s*(FOR|WHILE|LOOP)\b/i.test(lines[i])) depth++;
      if (/^\s*END\s+LOOP\s*;/i.test(lines[i])) {
        depth--;
        if (depth < 0) return i;
      }
    }
    return -1;
  }

  for (let i = startIdx; i < lines.length; i++) {
    if (pattern.test(lines[i])) return i;
  }
  return -1;
}

async function ensureCovTables(client: DbClient): Promise<void> {
  await client.query(`CREATE SCHEMA IF NOT EXISTS workbench`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.cov_run (
      id text PRIMARY KEY,
      schema_name text NOT NULL,
      fn_name text NOT NULL,
      started_at timestamptz DEFAULT now()
    )
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.cov_point (
      run_id text REFERENCES workbench.cov_run(id) ON DELETE CASCADE,
      id text,
      line int NOT NULL,
      kind text NOT NULL,
      label text NOT NULL,
      hit boolean DEFAULT false,
      PRIMARY KEY (run_id, id)
    )
  `);
}

/**
 * Run coverage analysis:
 * 1. Get DDL (backup) + parse AST -> coverage points
 * 2. Persist points in workbench tables
 * 3. Instrument body with RAISE WARNING markers
 * 4. Deploy instrumented version
 * 5. Run tests, capture notices via client.on('notice')
 * 6. Restore original version
 * 7. Batch UPDATE hits
 */
export async function runCoverage(
  client: DbClient,
  schema: string,
  name: string,
  testFn: (client: DbClient) => Promise<void>,
): Promise<CoverageResult | null> {
  const originalDdl = await queryFunctionDdl(client, schema, name);
  if (!originalDdl) return null;

  const points = await extractCoveragePoints(originalDdl);
  if (points.length === 0) {
    return { runId: "", schema, name, points, hit: new Set(), totalPoints: 0, coveredPoints: 0, percentage: 100 };
  }

  // Instrument — check before persisting to avoid orphaned rows
  const extracted = extractBody(originalDdl);
  if (!extracted) return null;

  // Persist coverage metadata
  await ensureCovTables(client);
  const runId = crypto.randomUUID().slice(0, 8);

  await client.query("BEGIN");
  try {
    await client.query(
      `INSERT INTO workbench.cov_run (id, schema_name, fn_name) VALUES ($1, $2, $3)`,
      [runId, schema, name],
    );
    for (const p of points) {
      await client.query(
        `INSERT INTO workbench.cov_point (run_id, id, line, kind, label) VALUES ($1, $2, $3, $4, $5)`,
        [runId, p.id, p.line, p.kind, p.label],
      );
    }
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK").catch(() => {});
    throw err;
  }

  const instrumentedBody = instrumentBody(extracted.body, points);
  const instrumentedDdl =
    originalDdl.slice(0, extracted.bodyStart) +
    instrumentedBody +
    originalDdl.slice(extracted.bodyStart + extracted.body.length);


  // Deploy + capture
  const hit = new Set<string>();

  const onNotice = (msg: { message?: string }) => {
    const text = msg.message ?? "";
    if (text.startsWith(COV_PREFIX)) {
      hit.add(text.slice(COV_PREFIX.length));
    }
  };

  try {
    client.on?.("notice", onNotice);
    await client.query(instrumentedDdl);
    await testFn(client);
  } finally {
    client.removeListener?.("notice", onNotice);
    try {
      await client.query(originalDdl);
    } catch {
      // best-effort restore
    }
  }

  // Batch UPDATE hits
  if (hit.size > 0) {
    await client.query(
      `UPDATE workbench.cov_point SET hit = true WHERE run_id = $1 AND id = ANY($2)`,
      [runId, [...hit]],
    );
  }

  const coveredPoints = points.filter((p) => hit.has(p.id)).length;
  const totalPoints = points.length;
  const percentage = totalPoints > 0 ? Math.round((coveredPoints / totalPoints) * 100) : 100;

  return { runId, schema, name, points, hit, totalPoints, coveredPoints, percentage };
}

export function formatCoverageReport(result: CoverageResult): string {
  const parts: string[] = [];
  const pct = result.percentage;
  const sym = pct === 100 ? "✓" : pct >= 80 ? "⚠" : "✗";
  parts.push(`${sym} ${result.schema}.${result.name}: ${pct}% coverage (${result.coveredPoints}/${result.totalPoints} points)`);
  if (result.runId) parts.push(`run: ${result.runId}`);
  parts.push("");

  const blocks = result.points.filter((p) => p.kind === "block");
  const branches = result.points.filter((p) => p.kind === "branch");

  if (blocks.length > 0) {
    const hitBlocks = blocks.filter((p) => result.hit.has(p.id));
    parts.push(`blocks: ${hitBlocks.length}/${blocks.length}`);
    for (const p of blocks) {
      const mark = result.hit.has(p.id) ? "✓" : "✗";
      parts.push(`  ${mark} line ${p.line}: ${p.label}`);
    }
  }

  if (branches.length > 0) {
    parts.push("");
    const hitBranches = branches.filter((p) => result.hit.has(p.id));
    parts.push(`branches: ${hitBranches.length}/${branches.length}`);
    for (const p of branches) {
      const mark = result.hit.has(p.id) ? "✓" : "✗";
      parts.push(`  ${mark} line ${p.line}: ${p.label}`);
    }
  }

  return parts.join("\n");
}
