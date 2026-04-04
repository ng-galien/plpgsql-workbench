import fs from "node:fs/promises";
import path from "node:path";
import type { DbClient } from "../connection.js";
import { hashContent } from "../pgm/plx-builder.js";

type RuntimeArtifactKind = "ddl" | "sql" | "test";

export interface RuntimeWorkflowArtifact {
  key: string;
  kind: RuntimeArtifactKind;
  name: string;
  file: string;
  content: string;
  hash: string;
}

export interface AppliedRuntimeArtifactState {
  key: string;
  kind: RuntimeArtifactKind;
  name: string;
  hash: string;
  file: string;
  appliedAt: string;
}

export interface PreparedRuntimeWorkflow {
  workspaceRoot: string;
  runtimeDir: string;
  targetDir: string;
  target: string;
  artifacts: RuntimeWorkflowArtifact[];
  buildFiles: string[];
  srcFiles: string[];
  testFiles: string[];
}

export interface RuntimeArtifactDiff {
  changed: RuntimeWorkflowArtifact[];
  unchanged: RuntimeWorkflowArtifact[];
  obsolete: AppliedRuntimeArtifactState[];
}

interface RuntimeApplyArtifactResult {
  key: string;
  kind: RuntimeArtifactKind;
  name: string;
  action: "applied" | "unchanged";
}

interface RuntimeApplyFailure {
  problem: string;
  stage: string;
  where: string;
  fixHint?: string;
}

export interface RuntimeApplyExecutionResult {
  ok: boolean;
  transaction: "not_started" | "committed" | "rolled_back";
  diff: RuntimeArtifactDiff;
  plan: RuntimeWorkflowArtifact[];
  results: RuntimeApplyArtifactResult[];
  warnings: string[];
  obsolete: AppliedRuntimeArtifactState[];
  failure?: RuntimeApplyFailure;
}

export async function prepareRuntimeWorkflow(workspaceRoot: string, target: string): Promise<PreparedRuntimeWorkflow> {
  const runtimeDir = path.join(workspaceRoot, "runtime");
  const targetDir = path.join(runtimeDir, target);
  const stats = await fs.stat(targetDir).catch(() => null);
  if (!stats?.isDirectory()) {
    throw new Error(`Runtime target '${target}' not found in runtime/`);
  }

  const buildFiles = await listSqlFiles(path.join(targetDir, "build"));
  const srcFiles = await listSqlFiles(path.join(targetDir, "src"));
  const testFiles = await listSqlFiles(path.join(targetDir, "tests"));
  const artifacts: RuntimeWorkflowArtifact[] = [];

  for (const file of buildFiles) {
    artifacts.push(await readArtifact(targetDir, "ddl", file));
  }

  if (testFiles.length > 0) {
    const testSchemaSql = `CREATE SCHEMA IF NOT EXISTS ${quoteIdent(`${target}_ut`)};`;
    artifacts.push({
      key: `ddl:schema:${target}_ut`,
      kind: "ddl",
      name: `${target}_ut`,
      file: "(generated)",
      content: testSchemaSql,
      hash: hashContent(testSchemaSql),
    });
  }

  for (const file of srcFiles) {
    artifacts.push(await readArtifact(targetDir, "sql", file));
  }

  for (const file of testFiles) {
    artifacts.push(await readArtifact(targetDir, "test", file));
  }

  return {
    workspaceRoot,
    runtimeDir,
    targetDir,
    target,
    artifacts,
    buildFiles,
    srcFiles,
    testFiles,
  };
}

export async function readAppliedRuntimeArtifacts(
  client: DbClient,
  target: string,
): Promise<{ available: boolean; states: Map<string, AppliedRuntimeArtifactState> }> {
  try {
    const { rows } = await client.query<{
      artifact_key: string;
      artifact_kind: RuntimeArtifactKind;
      artifact_name: string;
      artifact_hash: string;
      artifact_file: string;
      applied_at: string;
    }>(
      `SELECT artifact_key, artifact_kind, artifact_name, artifact_hash, artifact_file, applied_at::text
         FROM workbench.applied_runtime_artifact
        WHERE runtime_target = $1`,
      [target],
    );

    const states = new Map<string, AppliedRuntimeArtifactState>();
    for (const row of rows) {
      states.set(row.artifact_key, {
        key: row.artifact_key,
        kind: row.artifact_kind,
        name: row.artifact_name,
        hash: row.artifact_hash,
        file: row.artifact_file,
        appliedAt: row.applied_at,
      });
    }
    return { available: true, states };
  } catch (error: unknown) {
    const code = (error as { code?: string }).code;
    if (code === "42P01" || code === "3F000") {
      return { available: false, states: new Map() };
    }
    throw error;
  }
}

export function diffRuntimeArtifacts(
  artifacts: RuntimeWorkflowArtifact[],
  appliedState: Map<string, AppliedRuntimeArtifactState>,
): RuntimeArtifactDiff {
  const changed: RuntimeWorkflowArtifact[] = [];
  const unchanged: RuntimeWorkflowArtifact[] = [];

  for (const artifact of artifacts) {
    const applied = appliedState.get(artifact.key);
    if (applied?.hash === artifact.hash) unchanged.push(artifact);
    else changed.push(artifact);
  }

  const currentKeys = new Set(artifacts.map((artifact) => artifact.key));
  const obsolete = [...appliedState.values()].filter((state) => !currentKeys.has(state.key));
  return { changed, unchanged, obsolete };
}

export function sortRuntimeArtifacts(artifacts: RuntimeWorkflowArtifact[]): RuntimeWorkflowArtifact[] {
  const rank = (kind: RuntimeArtifactKind): number => {
    switch (kind) {
      case "ddl":
        return 0;
      case "sql":
        return 1;
      case "test":
        return 2;
    }
  };

  return [...artifacts].sort((left, right) => {
    const byKind = rank(left.kind) - rank(right.kind);
    if (byKind !== 0) return byKind;
    if (left.kind === "ddl" && right.kind === "ddl") {
      const leftGenerated = left.file === "(generated)";
      const rightGenerated = right.file === "(generated)";
      if (leftGenerated !== rightGenerated) return leftGenerated ? 1 : -1;
    }
    return left.file.localeCompare(right.file);
  });
}

export async function applyRuntimeIncremental(
  client: DbClient,
  workflow: PreparedRuntimeWorkflow,
): Promise<RuntimeApplyExecutionResult> {
  await ensureRuntimeTrackingTable(client);

  const applied = await readAppliedRuntimeArtifacts(client, workflow.target);
  const diff = diffRuntimeArtifacts(workflow.artifacts, applied.states);
  if (diff.changed.length === 0) {
    return {
      ok: true,
      transaction: "not_started",
      diff,
      plan: [],
      obsolete: diff.obsolete,
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      results: diff.unchanged.map((artifact) => ({
        key: artifact.key,
        kind: artifact.kind,
        name: artifact.name,
        action: "unchanged",
      })),
    };
  }

  const plan = sortRuntimeArtifacts(diff.changed);
  const results: RuntimeApplyArtifactResult[] = [];

  await client.query("BEGIN");
  try {
    for (const artifact of plan) {
      await client.query(artifact.content);
      results.push({ key: artifact.key, kind: artifact.kind, name: artifact.name, action: "applied" });
      await client.query(
        `INSERT INTO workbench.applied_runtime_artifact
           (runtime_target, artifact_key, artifact_kind, artifact_name, artifact_file, artifact_hash, applied_at)
         VALUES ($1, $2, $3, $4, $5, $6, now())
         ON CONFLICT (runtime_target, artifact_key)
         DO UPDATE SET
           artifact_kind = EXCLUDED.artifact_kind,
           artifact_name = EXCLUDED.artifact_name,
           artifact_file = EXCLUDED.artifact_file,
           artifact_hash = EXCLUDED.artifact_hash,
           applied_at = now()`,
        [workflow.target, artifact.key, artifact.kind, artifact.name, artifact.file, artifact.hash],
      );
    }

    await client.query("COMMIT");
    await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});
    return {
      ok: true,
      transaction: "committed",
      diff,
      plan,
      obsolete: diff.obsolete,
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      results,
    };
  } catch (error: unknown) {
    await client.query("ROLLBACK").catch(() => {});
    return {
      ok: false,
      transaction: "rolled_back",
      diff,
      plan,
      obsolete: diff.obsolete,
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      results,
      failure: toApplyFailure(error),
    };
  }
}

async function ensureRuntimeTrackingTable(client: DbClient): Promise<void> {
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.applied_runtime_artifact (
      runtime_target text NOT NULL,
      artifact_key text NOT NULL,
      artifact_kind text NOT NULL,
      artifact_name text NOT NULL,
      artifact_file text NOT NULL,
      artifact_hash text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (runtime_target, artifact_key)
    )
  `);
}

async function readArtifact(
  targetDir: string,
  kind: RuntimeArtifactKind,
  relativeFile: string,
): Promise<RuntimeWorkflowArtifact> {
  const absoluteFile = path.join(targetDir, relativeFile);
  const content = await fs.readFile(absoluteFile, "utf-8");
  return {
    key: `${kind}:${relativeFile}`,
    kind,
    name: path.basename(relativeFile, ".sql"),
    file: relativeFile,
    content,
    hash: hashContent(content),
  };
}

async function listSqlFiles(dir: string): Promise<string[]> {
  const stats = await fs.stat(dir).catch(() => null);
  if (!stats?.isDirectory()) return [];
  const entries = await fs.readdir(dir, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".sql"))
    .map((entry) => path.join(path.basename(dir), entry.name).split(path.sep).join("/"))
    .sort();
}

function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

function toApplyFailure(error: unknown): RuntimeApplyFailure {
  const message = error instanceof Error ? error.message : String(error);
  return {
    problem: message,
    stage: "apply",
    where: "runtime_apply",
    fixHint: "inspect the SQL artifact order and failing runtime schema object",
  };
}
