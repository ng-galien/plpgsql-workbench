import fs from "node:fs/promises";
import path from "node:path";
import type { DbClient } from "../connection.js";
import { quoteIdent } from "../sql.js";
import {
  ensureAppliedArtifactTable,
  readAppliedArtifactStates,
  upsertAppliedArtifactState,
} from "../tooling/primitives/applied-artifacts.js";
import { notifyPostgrestSchemaReload } from "../tooling/primitives/postgrest.js";
import { withTransaction } from "../tooling/primitives/transaction.js";
import { hashContent, type PreparedPlxModule, preparePlxModule, writePreparedBuildFiles } from "./plx-builder.js";
import { loadManifest, type ModuleManifest } from "./resolver.js";

type ModuleWorkflowArtifactKind = "extension" | "ddl" | "function" | "test" | "grant";

export interface ModuleWorkflowArtifact {
  key: string;
  kind: ModuleWorkflowArtifactKind;
  name: string;
  file?: string;
  content: string;
  hash: string;
  dependsOn: string[];
}

export interface ModuleBuildFileStatus {
  kind: "ddl" | "func" | "test";
  file?: string;
  expectedHash?: string;
  currentHash?: string;
  status: "up_to_date" | "stale" | "missing" | "not_generated" | "unconfigured";
}

export interface AppliedArtifactState {
  key: string;
  kind: ModuleWorkflowArtifactKind;
  name: string;
  hash: string;
  file?: string;
  appliedAt: string;
}

interface ModuleArtifactDiff {
  changed: ModuleWorkflowArtifact[];
  unchanged: ModuleWorkflowArtifact[];
  obsolete: AppliedArtifactState[];
}

export interface PreparedModuleWorkflow {
  workspaceRoot: string;
  modulesDir: string;
  moduleDir: string;
  manifest: ModuleManifest;
  prepared: PreparedPlxModule;
  artifacts: ModuleWorkflowArtifact[];
  buildFiles: ModuleBuildFileStatus[];
}

interface ModuleApplyFailure {
  problem: string;
  stage: string;
  where: string;
  fixHint?: string;
}

interface ModuleApplyArtifactResult {
  key: string;
  kind: ModuleWorkflowArtifactKind;
  name: string;
  action: "applied" | "unchanged";
  warning?: string;
}

interface ModuleApplyExecutionResult {
  ok: boolean;
  transaction: "not_started" | "committed" | "rolled_back";
  diff: ModuleArtifactDiff;
  plan: ModuleWorkflowArtifact[];
  results: ModuleApplyArtifactResult[];
  warnings: string[];
  obsolete: AppliedArtifactState[];
  buildFiles: string[];
  postActions: string[];
  failure?: ModuleApplyFailure;
}

export async function prepareModuleWorkflow(
  workspaceRoot: string,
  moduleName: string,
  options: { validate?: boolean } = { validate: false },
): Promise<PreparedModuleWorkflow> {
  const modulesDir = path.join(workspaceRoot, "modules");
  const manifest = await loadManifest(modulesDir, moduleName);
  if (!manifest.plx?.entry) {
    throw new Error(`Module '${moduleName}' has no plx.entry`);
  }

  const moduleDir = path.join(modulesDir, moduleName);
  const prepared = await preparePlxModule(modulesDir, manifest, options);
  const artifacts = [...buildManifestArtifacts(manifest), ...prepared.artifacts];
  const buildFiles = await collectBuildFileStatus(moduleDir, prepared);

  return {
    workspaceRoot,
    modulesDir,
    moduleDir,
    manifest,
    prepared,
    artifacts,
    buildFiles,
  };
}

export function diffModuleArtifacts(
  artifacts: ModuleWorkflowArtifact[],
  appliedState: Map<string, AppliedArtifactState>,
): ModuleArtifactDiff {
  const changed: ModuleWorkflowArtifact[] = [];
  const unchanged: ModuleWorkflowArtifact[] = [];

  for (const artifact of artifacts) {
    const applied = appliedState.get(artifact.key);
    if (applied?.hash === artifact.hash) unchanged.push(artifact);
    else changed.push(artifact);
  }

  const currentKeys = new Set(artifacts.map((artifact) => artifact.key));
  const obsolete = [...appliedState.values()].filter((state) => !currentKeys.has(state.key));

  return { changed, unchanged, obsolete };
}

export async function readAppliedArtifacts(
  client: DbClient,
  moduleName: string,
): Promise<{ available: boolean; states: Map<string, AppliedArtifactState> }> {
  const result = await readAppliedArtifactStates<ModuleWorkflowArtifactKind>(client, {
    table: "applied_module_artifact",
    scopeColumn: "module_name",
    scopeValue: moduleName,
  });
  return { available: result.available, states: result.states as Map<string, AppliedArtifactState> };
}

export async function applyModuleIncremental(
  client: DbClient,
  workflow: PreparedModuleWorkflow,
): Promise<ModuleApplyExecutionResult> {
  const buildFiles = await syncModuleBuildFiles(workflow);
  await ensureAppliedArtifactTable(client, {
    table: "applied_module_artifact",
    scopeColumn: "module_name",
  });

  const applied = await readAppliedArtifacts(client, workflow.manifest.name);
  const diff = diffModuleArtifacts(workflow.artifacts, applied.states);
  if (diff.changed.length === 0) {
    return {
      ok: true,
      transaction: "not_started",
      diff,
      plan: [],
      obsolete: diff.obsolete,
      buildFiles,
      postActions: [],
      results: diff.unchanged.map((artifact) => ({
        key: artifact.key,
        kind: artifact.kind,
        name: artifact.name,
        action: "unchanged",
      })),
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
    };
  }

  let ordered: ModuleWorkflowArtifact[];
  try {
    ordered = sortApplyArtifacts(diff.changed);
  } catch (error: unknown) {
    return {
      ok: false,
      transaction: "not_started",
      diff,
      plan: [],
      obsolete: diff.obsolete,
      buildFiles,
      postActions: [],
      results: [],
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      failure: toApplyFailure(error, "plx_apply.ordering"),
    };
  }
  const results: ModuleApplyArtifactResult[] = [];
  const warnings: string[] = [];
  let committedResult: ModuleApplyExecutionResult | undefined;

  try {
    await withTransaction(client, async () => {
      for (const artifact of ordered) {
        if (artifact.kind === "function") {
          const fnWarning = await applyFunctionArtifact(client, artifact);
          results.push({
            key: artifact.key,
            kind: artifact.kind,
            name: artifact.name,
            action: "applied",
            warning: fnWarning,
          });
          if (fnWarning) warnings.push(fnWarning);
        } else {
          await client.query(artifact.content);
          results.push({
            key: artifact.key,
            kind: artifact.kind,
            name: artifact.name,
            action: "applied",
          });
        }

        await upsertAppliedArtifactState(
          client,
          {
            table: "applied_module_artifact",
            scopeColumn: "module_name",
            scopeValue: workflow.manifest.name,
          },
          artifact,
          artifact.file,
        );
      }
    });
    await notifyPostgrestSchemaReload(client);
    committedResult = {
      ok: true,
      transaction: "committed",
      diff,
      plan: ordered,
      obsolete: diff.obsolete,
      buildFiles,
      postActions: [],
      results: [
        ...results,
        ...diff.unchanged.map((artifact) => ({
          key: artifact.key,
          kind: artifact.kind,
          name: artifact.name,
          action: "unchanged" as const,
        })),
      ],
      warnings: [
        ...warnings,
        ...diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      ],
    };
  } catch (error: unknown) {
    return {
      ok: false,
      transaction: "rolled_back",
      diff,
      plan: ordered,
      obsolete: diff.obsolete,
      buildFiles,
      postActions: [],
      results,
      warnings,
      failure: toApplyFailure(error),
    };
  }

  // Post-apply runs outside the transaction: a failure here is independent of the apply result.
  if (!committedResult) {
    throw new Error("module apply committed without a result payload");
  }
  const postActions = await runModulePostApply(client, workflow.manifest);
  return { ...committedResult, postActions };
}

async function runModulePostApply(client: DbClient, manifest: ModuleManifest): Promise<string[]> {
  const actions: string[] = [];
  const seeded = await runModuleI18nSeed(client, manifest);
  if (seeded) actions.push(seeded);
  return actions;
}

export async function runModuleI18nSeed(client: DbClient, manifest: ModuleManifest): Promise<string | undefined> {
  const schema = manifest.schemas.public;
  if (!schema) return undefined;

  const { rows } = await client.query<{ present: number }>(
    `SELECT 1 AS present
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1 AND p.proname = 'i18n_seed'`,
    [schema],
  );
  if (rows.length === 0) return undefined;

  await client.query(`SELECT ${quoteIdent(schema)}.i18n_seed()`);
  return `seeded i18n ${schema}.i18n_seed()`;
}

export async function syncModuleBuildFiles(workflow: PreparedModuleWorkflow): Promise<string[]> {
  const written = await writePreparedBuildFiles(workflow.moduleDir, workflow.prepared, workflow.manifest.name);
  workflow.buildFiles = await collectBuildFileStatus(workflow.moduleDir, workflow.prepared);
  return written;
}

async function collectBuildFileStatus(
  moduleDir: string,
  prepared: PreparedPlxModule,
): Promise<ModuleBuildFileStatus[]> {
  const entries: ModuleBuildFileStatus[] = [];
  const outputs = [
    { kind: "ddl" as const, output: prepared.outputs.ddl },
    { kind: "func" as const, output: prepared.outputs.func },
    { kind: "test" as const, output: prepared.outputs.test },
  ];

  for (const entry of outputs) {
    const output = entry.output;
    if (!output) {
      entries.push({ kind: entry.kind, status: "not_generated" });
      continue;
    }
    if (!output.file) {
      entries.push({
        kind: entry.kind,
        status: "unconfigured",
        expectedHash: output.hash,
      });
      continue;
    }

    const filePath = path.join(moduleDir, output.file);
    let currentHash: string | undefined;
    try {
      const content = await fs.readFile(filePath, "utf-8");
      currentHash = hashContent(content);
    } catch {
      entries.push({
        kind: entry.kind,
        file: output.file,
        expectedHash: output.hash,
        status: "missing",
      });
      continue;
    }

    entries.push({
      kind: entry.kind,
      file: output.file,
      expectedHash: output.hash,
      currentHash,
      status: currentHash === output.hash ? "up_to_date" : "stale",
    });
  }

  return entries;
}

function buildManifestArtifacts(manifest: ModuleManifest): ModuleWorkflowArtifact[] {
  const artifacts: ModuleWorkflowArtifact[] = [];

  if (manifest.extensions.length > 0) {
    const content = manifest.extensions.map((ext) => `CREATE EXTENSION IF NOT EXISTS ${quoteIdent(ext)};`).join("\n");
    artifacts.push({
      key: "extensions",
      kind: "extension",
      name: `${manifest.name}.extensions`,
      content,
      hash: hashContent(content),
      dependsOn: [],
    });
  }

  const grantStatements: string[] = [];
  for (const [role, schemas] of Object.entries(manifest.grants ?? {})) {
    for (const schema of schemas) {
      grantStatements.push(`GRANT USAGE ON SCHEMA ${quoteIdent(schema)} TO ${quoteIdent(role)};`);
      grantStatements.push(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${quoteIdent(schema)} TO ${quoteIdent(role)};`);
      grantStatements.push(`GRANT SELECT ON ALL TABLES IN SCHEMA ${quoteIdent(schema)} TO ${quoteIdent(role)};`);
    }
  }
  if (grantStatements.length > 0) {
    const content = grantStatements.join("\n");
    artifacts.push({
      key: "grants",
      kind: "grant",
      name: `${manifest.name}.grants`,
      content,
      hash: hashContent(content),
      dependsOn: [],
    });
  }

  return artifacts;
}

async function applyFunctionArtifact(client: DbClient, artifact: ModuleWorkflowArtifact): Promise<string | undefined> {
  const [schema, name] = artifact.name.split(".");
  if (!schema || !name) {
    throw new Error(`invalid function artifact name '${artifact.name}'`);
  }

  const beforeSignatures = await listFunctionIdentityArgs(client, schema, name);
  await client.query(artifact.content);
  let afterSignatures = await listFunctionIdentityArgs(client, schema, name);
  let replacementWarning: string | undefined;
  if (afterSignatures.length > 1 && afterSignatures.length > beforeSignatures.length) {
    const added = afterSignatures.filter((signature) => !beforeSignatures.includes(signature));
    if (beforeSignatures.length === 1 && added.length === 1) {
      await dropFunctionByIdentityArgs(client, schema, name, beforeSignatures[0] ?? "");
      afterSignatures = await listFunctionIdentityArgs(client, schema, name);
      replacementWarning = `replaced signature ${schema}.${name}(${beforeSignatures[0] ?? ""}) -> (${added[0] ?? ""})`;
    }
  }
  if (afterSignatures.length > 1) {
    throw new Error(
      `overload interdit: ${schema}.${name} had ${beforeSignatures.length} signature(s), apply would leave ${afterSignatures.length} total`,
    );
  }
  return replacementWarning;
}

async function listFunctionIdentityArgs(client: DbClient, schema: string, name: string): Promise<string[]> {
  const { rows } = await client.query<{ identity_args: string }>(
    `SELECT pg_get_function_identity_arguments(p.oid) AS identity_args
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1 AND p.proname = $2
      ORDER BY p.oid`,
    [schema, name],
  );
  return rows.map((row) => row.identity_args);
}

async function dropFunctionByIdentityArgs(
  client: DbClient,
  schema: string,
  name: string,
  identityArgs: string,
): Promise<void> {
  const dropSql =
    identityArgs.trim().length > 0
      ? `DROP FUNCTION IF EXISTS ${quoteIdent(schema)}.${quoteIdent(name)}(${identityArgs})`
      : `DROP FUNCTION IF EXISTS ${quoteIdent(schema)}.${quoteIdent(name)}()`;
  await client.query(dropSql);
}

export function sortApplyArtifacts(artifacts: ModuleWorkflowArtifact[]): ModuleWorkflowArtifact[] {
  if (artifacts.length <= 1) return [...artifacts];

  const byKey = new Map(artifacts.map((artifact) => [artifact.key, artifact]));
  const outgoing = new Map<string, Set<string>>();
  const indegree = new Map<string, number>();

  for (const artifact of artifacts) {
    outgoing.set(artifact.key, new Set());
    indegree.set(artifact.key, 0);
  }

  for (const artifact of artifacts) {
    for (const dependencyKey of resolveArtifactDependencies(artifact, byKey)) {
      const targets = outgoing.get(dependencyKey);
      if (!targets || targets.has(artifact.key)) continue;
      targets.add(artifact.key);
      indegree.set(artifact.key, (indegree.get(artifact.key) ?? 0) + 1);
    }
  }

  const ready = artifacts.filter((artifact) => (indegree.get(artifact.key) ?? 0) === 0).sort(compareArtifacts);
  const ordered: ModuleWorkflowArtifact[] = [];

  while (ready.length > 0) {
    const next = ready.shift();
    if (!next) break;
    ordered.push(next);

    for (const dependentKey of outgoing.get(next.key) ?? []) {
      const remaining = (indegree.get(dependentKey) ?? 0) - 1;
      indegree.set(dependentKey, remaining);
      if (remaining === 0) {
        const dependent = byKey.get(dependentKey);
        if (dependent) {
          ready.push(dependent);
          ready.sort(compareArtifacts);
        }
      }
    }
  }

  if (ordered.length === artifacts.length) return ordered;

  const cycle = findArtifactCycle(artifacts, byKey);
  const rendered = cycle.map((artifact) => `${artifact.kind} ${artifact.name}`).join(" -> ");
  throw new Error(
    `artifact dependency cycle detected: ${rendered}. Break the cycle or split the module so artifacts can be applied deterministically.`,
  );
}

function resolveArtifactDependencies(
  artifact: ModuleWorkflowArtifact,
  artifactsByKey: Map<string, ModuleWorkflowArtifact>,
): string[] {
  const dependencies = new Set(artifact.dependsOn.filter((key) => artifactsByKey.has(key)));
  const extensions = [...artifactsByKey.values()].filter((candidate) => candidate.kind === "extension");
  const ddl = [...artifactsByKey.values()].filter((candidate) => candidate.kind === "ddl");
  const functions = [...artifactsByKey.values()].filter((candidate) => candidate.kind === "function");

  switch (artifact.kind) {
    case "extension":
      break;
    case "ddl":
      for (const candidate of extensions) dependencies.add(candidate.key);
      break;
    case "function":
      for (const candidate of extensions) dependencies.add(candidate.key);
      for (const candidate of ddl) dependencies.add(candidate.key);
      break;
    case "test":
      for (const candidate of extensions) dependencies.add(candidate.key);
      for (const candidate of ddl) dependencies.add(candidate.key);
      for (const candidate of functions) dependencies.add(candidate.key);
      break;
    case "grant":
      for (const candidate of artifactsByKey.values()) {
        if (candidate.key !== artifact.key) dependencies.add(candidate.key);
      }
      break;
  }

  dependencies.delete(artifact.key);
  return [...dependencies];
}

function findArtifactCycle(
  artifacts: ModuleWorkflowArtifact[],
  artifactsByKey: Map<string, ModuleWorkflowArtifact>,
): ModuleWorkflowArtifact[] {
  const visiting = new Set<string>();
  const visited = new Set<string>();
  const stack: string[] = [];

  const visit = (key: string): ModuleWorkflowArtifact[] | null => {
    if (visiting.has(key)) {
      const start = stack.indexOf(key);
      const cycleKeys = start >= 0 ? [...stack.slice(start), key] : [key, key];
      return cycleKeys
        .map((cycleKey) => artifactsByKey.get(cycleKey))
        .filter((artifact): artifact is ModuleWorkflowArtifact => Boolean(artifact));
    }
    if (visited.has(key)) return null;

    visiting.add(key);
    stack.push(key);

    const artifact = artifactsByKey.get(key);
    if (artifact) {
      for (const dependencyKey of resolveArtifactDependencies(artifact, artifactsByKey)) {
        const cycle = visit(dependencyKey);
        if (cycle) return cycle;
      }
    }

    stack.pop();
    visiting.delete(key);
    visited.add(key);
    return null;
  };

  for (const artifact of artifacts.sort(compareArtifacts)) {
    const cycle = visit(artifact.key);
    if (cycle) return cycle;
  }

  return artifacts.sort(compareArtifacts);
}

function compareArtifacts(left: ModuleWorkflowArtifact, right: ModuleWorkflowArtifact): number {
  const delta = rankArtifactKind(left.kind) - rankArtifactKind(right.kind);
  return delta !== 0 ? delta : left.name.localeCompare(right.name);
}

function rankArtifactKind(kind: ModuleWorkflowArtifactKind): number {
  const rank: Record<ModuleWorkflowArtifactKind, number> = {
    extension: 0,
    ddl: 1,
    function: 2,
    test: 3,
    grant: 4,
  };
  return rank[kind];
}

function toApplyFailure(error: unknown, where = "plx_apply"): ModuleApplyFailure {
  const message = error instanceof Error ? error.message : String(error);
  return {
    problem: message,
    stage: where.replace(/^plx_apply\.?/, "") || "apply",
    where,
    fixHint:
      where === "plx_apply.ordering"
        ? "Break the artifact dependency cycle or split the module so artifacts can be applied in a deterministic order."
        : undefined,
  };
}
