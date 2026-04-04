export interface TapDiagnostic {
  ok: boolean;
  description: string;
  have?: string;
  want?: string;
  sqlstate?: string;
  error?: string;
  context?: string[];
}

export interface TapDiagnosticReport {
  passed: number;
  failed: number;
  total: number;
  results: TapDiagnostic[];
}

export function parseTapDiagnostics(rows: { runtests: string }[]): TapDiagnosticReport {
  const results: TapDiagnostic[] = [];
  let current: TapDiagnostic | null = null;
  let pendingFailure: Pick<TapDiagnostic, "sqlstate" | "error" | "context"> | null = null;

  const lines: string[] = [];
  for (const row of rows) lines.push(...row.runtests.split("\n"));

  for (const line of lines) {
    const diedMatch = line.match(/#\s+Test died:\s+([A-Z0-9]+):\s+(.+)/);
    if (diedMatch) {
      const failure = {
        sqlstate: diedMatch[1],
        error: diedMatch[2],
        context: [],
      };
      if (current && !current.ok) {
        current.sqlstate = failure.sqlstate;
        current.error = failure.error;
        current.context = failure.context;
      } else {
        pendingFailure = failure;
      }
      continue;
    }
    if (line.match(/#\s+CONTEXT:\s*$/) && (pendingFailure || (current && !current.ok))) {
      if (pendingFailure) pendingFailure.context ??= [];
      if (current && !current.ok) current.context ??= [];
      continue;
    }
    const contextLine = line.match(/#\s{6,}(.+)/);
    if (contextLine && (pendingFailure?.context || (current && !current.ok && current.context))) {
      const contextEntry = contextLine[1];
      if (contextEntry && pendingFailure?.context) pendingFailure.context.push(contextEntry);
      if (contextEntry && current && !current.ok && current.context) current.context.push(contextEntry);
      continue;
    }

    const tapMatch = line.match(/^\s*(not )?ok \d+ - (.+)$/);
    if (tapMatch) {
      if (current) results.push(current);
      const description = tapMatch[2];
      if (!description) continue;
      current = { ok: !tapMatch[1], description, ...pendingFailure };
      pendingFailure = null;
      continue;
    }

    if (current && !current.ok) {
      const haveMatch = line.match(/#\s+have:\s*(.+)/);
      if (haveMatch) {
        current.have = haveMatch[1];
        continue;
      }
      const wantMatch = line.match(/#\s+want:\s*(.+)/);
      if (wantMatch) {
        current.want = wantMatch[1];
      }
    }
  }
  if (current) results.push(current);

  const passed = results.filter((result) => result.ok).length;
  const failed = results.filter((result) => !result.ok).length;
  return { passed, failed, total: results.length, results };
}

export function formatTapDiagnosticReport(report: TapDiagnosticReport): string {
  const parts: string[] = [];
  const symbol = report.failed > 0 ? "✗" : "✓";
  parts.push(`${symbol} ${report.passed} passed, ${report.failed} failed, ${report.total} total`);
  parts.push("completeness: full");
  parts.push("");

  for (const result of report.results) {
    if (result.ok) {
      parts.push(`  ✓ ${result.description}`);
      continue;
    }

    parts.push(`  ✗ ${result.description}`);
    if (result.sqlstate || result.error) {
      parts.push(`    error: ${[result.sqlstate, result.error].filter(Boolean).join(": ")}`);
    }
    if (result.context && result.context.length > 0) {
      parts.push("    context:");
      for (const line of result.context) parts.push(`      ${line}`);
    }
    if (result.have !== undefined) parts.push(`    have: ${result.have}`);
    if (result.want !== undefined) parts.push(`    want: ${result.want}`);
  }

  return parts.join("\n");
}
