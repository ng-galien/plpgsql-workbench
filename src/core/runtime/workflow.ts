import fs from "node:fs/promises";
import path from "node:path";
import type { DbClient } from "../connection.js";
import { hashContent } from "../pgm/plx-builder.js";
import {
  diffAppliedArtifacts,
  ensureAppliedArtifactTable,
  readAppliedArtifactStates,
  upsertAppliedArtifactState,
} from "../tooling/primitives/applied-artifacts.js";
import { notifyPostgrestSchemaReload } from "../tooling/primitives/postgrest.js";
import { withTransaction } from "../tooling/primitives/transaction.js";

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

  const [buildFiles, srcFiles, testFiles] = await Promise.all([
    listSqlFiles(path.join(targetDir, "build")),
    listSqlFiles(path.join(targetDir, "src")),
    listSqlFiles(path.join(targetDir, "tests")),
  ]);

  const [buildArtifacts, srcArtifacts, testArtifacts] = await Promise.all([
    Promise.all(buildFiles.map((file) => readArtifact(targetDir, "ddl", file))),
    Promise.all(srcFiles.map((file) => readArtifact(targetDir, "sql", file))),
    Promise.all(testFiles.map((file) => readArtifact(targetDir, "test", file))),
  ]);

  const artifacts: RuntimeWorkflowArtifact[] = [...buildArtifacts];

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

  artifacts.push(...srcArtifacts, ...testArtifacts);

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
  const result = await readAppliedArtifactStates<RuntimeArtifactKind>(client, {
    table: "applied_runtime_artifact",
    scopeColumn: "runtime_target",
    scopeValue: target,
  });
  return { available: result.available, states: result.states as Map<string, AppliedRuntimeArtifactState> };
}

export function diffRuntimeArtifacts(
  artifacts: RuntimeWorkflowArtifact[],
  appliedState: Map<string, AppliedRuntimeArtifactState>,
): RuntimeArtifactDiff {
  return diffAppliedArtifacts(artifacts, appliedState);
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
  await ensureAppliedArtifactTable(client, {
    table: "applied_runtime_artifact",
    scopeColumn: "runtime_target",
  });

  const applied = await readAppliedRuntimeArtifacts(client, workflow.target);
  const diff = diffRuntimeArtifacts(workflow.artifacts, applied.states);
  const warnings = diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`);

  if (diff.changed.length === 0) {
    return {
      ok: true,
      transaction: "not_started",
      diff,
      plan: [],
      obsolete: diff.obsolete,
      warnings,
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

  try {
    await withTransaction(client, async () => {
      for (const artifact of plan) {
        await client.query(artifact.content);
        results.push({ key: artifact.key, kind: artifact.kind, name: artifact.name, action: "applied" });
        await upsertAppliedArtifactState(
          client,
          {
            table: "applied_runtime_artifact",
            scopeColumn: "runtime_target",
            scopeValue: workflow.target,
          },
          artifact,
          artifact.file,
        );
      }
    });
    await notifyPostgrestSchemaReload(client);
    return { ok: true, transaction: "committed", diff, plan, obsolete: diff.obsolete, warnings, results };
  } catch (error: unknown) {
    return {
      ok: false,
      transaction: "rolled_back",
      diff,
      plan,
      obsolete: diff.obsolete,
      warnings,
      results,
      failure: toApplyFailure(error),
    };
  }
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
