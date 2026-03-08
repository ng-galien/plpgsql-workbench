import { parsePlPgSQL, loadModule } from "@libpg-query/parser";

let moduleLoaded = false;
async function ensureModule(): Promise<void> {
  if (!moduleLoaded) {
    await loadModule();
    moduleLoaded = true;
  }
}

export type PointKind = "block" | "branch";
export type InjectMode = "before" | "inject_else" | "inject_after_loop";

export interface CoveragePoint {
  id: string;
  line: number;       // body-relative (prosrc), 1-indexed
  kind: PointKind;
  label: string;
  inject: InjectMode; // how to inject the marker
  searchAfter?: number; // for inject_else/inject_after_loop: search for END IF/LOOP after this line
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Stmt = any;

let nextId = 0;
function pointId(): string { return `p${nextId++}`; }

/**
 * Parse a CREATE FUNCTION DDL and extract all coverage points from the body.
 */
export async function extractCoveragePoints(ddl: string): Promise<CoveragePoint[]> {
  await ensureModule();
  nextId = 0;

  const result: Stmt = await parsePlPgSQL(ddl);
  const func = result.plpgsql_funcs?.[0]?.PLpgSQL_function;
  if (!func) return [];

  const points: CoveragePoint[] = [];
  const body = func.action?.PLpgSQL_stmt_block?.body;
  if (body) walkStmts(body, points);
  return points;
}

function walkStmts(stmts: Stmt[], points: CoveragePoint[]): void {
  for (const stmt of stmts) walkStmt(stmt, points);
}

function walkStmt(stmt: Stmt, points: CoveragePoint[]): void {
  // --- Leaf statements (block coverage) ---
  for (const key of [
    "PLpgSQL_stmt_assign",
    "PLpgSQL_stmt_perform",
    "PLpgSQL_stmt_execsql",
    "PLpgSQL_stmt_return",
    "PLpgSQL_stmt_return_next",
    "PLpgSQL_stmt_raise",
    "PLpgSQL_stmt_dynexecute",
  ]) {
    if (stmt[key]?.lineno) {
      points.push({ id: pointId(), line: stmt[key].lineno, kind: "block", label: key.replace("PLpgSQL_stmt_", ""), inject: "before" });
    }
  }

  // --- IF / ELSIF / ELSE (branch coverage) ---
  if (stmt.PLpgSQL_stmt_if) {
    const s = stmt.PLpgSQL_stmt_if;
    const ifLine = s.lineno;

    // THEN branch
    if (s.then_body?.length > 0) {
      const firstLine = firstLineno(s.then_body);
      if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `IF true @${ifLine}`, inject: "before" });
      walkStmts(s.then_body, points);
    }

    // ELSIF branches
    for (const elsif of s.elsif_list ?? []) {
      const el = elsif.PLpgSQL_if_elsif;
      if (el?.stmts?.length > 0) {
        const firstLine = firstLineno(el.stmts);
        if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `ELSIF true @${el.lineno}`, inject: "before" });
        walkStmts(el.stmts, points);
      }
    }

    // ELSE branch
    if (s.else_body?.length > 0) {
      const firstLine = firstLineno(s.else_body);
      if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `ELSE @${ifLine}`, inject: "before" });
      walkStmts(s.else_body, points);
    }

    // IF without ELSE → inject synthetic ELSE before END IF
    if (!s.else_body) {
      const lastBody = s.elsif_list?.length > 0
        ? lastLineno(s.elsif_list[s.elsif_list.length - 1].PLpgSQL_if_elsif?.stmts ?? [])
        : lastLineno(s.then_body ?? []);
      if (lastBody) {
        points.push({
          id: pointId(), line: 0, kind: "branch",
          label: `IF false @${ifLine}`,
          inject: "inject_else", searchAfter: lastBody,
        });
      }
    }
  }

  // --- CASE / WHEN ---
  if (stmt.PLpgSQL_stmt_case) {
    const s = stmt.PLpgSQL_stmt_case;
    for (const w of s.case_when_list ?? []) {
      const cw = w.PLpgSQL_case_when;
      if (cw?.stmts?.length > 0) {
        const firstLine = firstLineno(cw.stmts);
        if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `WHEN @${cw.lineno}`, inject: "before" });
        walkStmts(cw.stmts, points);
      }
    }
    if (s.else_stmts?.length > 0) {
      const firstLine = firstLineno(s.else_stmts);
      if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `CASE ELSE @${s.lineno}`, inject: "before" });
      walkStmts(s.else_stmts, points);
    }
  }

  // --- Loops ---
  for (const key of [
    "PLpgSQL_stmt_loop",
    "PLpgSQL_stmt_while",
    "PLpgSQL_stmt_fori",
    "PLpgSQL_stmt_fors",
    "PLpgSQL_stmt_forc",
    "PLpgSQL_stmt_foreach_a",
  ]) {
    if (stmt[key]) {
      const s = stmt[key];
      // "loop body entered" — marker inside loop body
      if (s.body?.length > 0) {
        const firstLine = firstLineno(s.body);
        if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `loop enter @${s.lineno}`, inject: "before" });
        walkStmts(s.body, points);
      }
      // "loop skipped" — inject marker after END LOOP
      if (s.lineno && key !== "PLpgSQL_stmt_loop") {
        // PLpgSQL_stmt_loop is unconditional (LOOP...END LOOP) — always entered, skip detection not needed
        const lastBody = lastLineno(s.body ?? []);
        if (lastBody) {
          points.push({
            id: pointId(), line: 0, kind: "branch",
            label: `loop skip @${s.lineno}`,
            inject: "inject_after_loop", searchAfter: lastBody,
          });
        }
      }
    }
  }

  // --- Nested block + exception handlers ---
  if (stmt.PLpgSQL_stmt_block) {
    const s = stmt.PLpgSQL_stmt_block;
    if (s.body) walkStmts(s.body, points);
    if (s.exceptions?.PLpgSQL_exception_block?.exc_list) {
      for (const exc of s.exceptions.PLpgSQL_exception_block.exc_list) {
        const e = exc.PLpgSQL_exception;
        if (e?.action?.length > 0) {
          const firstLine = firstLineno(e.action);
          const condNames = (e.conditions ?? [])
            .map((c: Stmt) => c.PLpgSQL_condition?.condname ?? "?")
            .join(", ");
          if (firstLine) points.push({ id: pointId(), line: firstLine, kind: "branch", label: `EXCEPTION ${condNames}`, inject: "before" });
          walkStmts(e.action, points);
        }
      }
    }
  }
}

function firstLineno(stmts: Stmt[]): number | null {
  for (const s of stmts) {
    for (const key of Object.keys(s)) {
      if (s[key]?.lineno) return s[key].lineno;
    }
  }
  return null;
}

function lastLineno(stmts: Stmt[]): number | null {
  for (let i = stmts.length - 1; i >= 0; i--) {
    for (const key of Object.keys(stmts[i])) {
      if (stmts[i][key]?.lineno) return stmts[i][key].lineno;
    }
  }
  return null;
}
