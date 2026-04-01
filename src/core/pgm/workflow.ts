import fs from "node:fs/promises";
import path from "node:path";
import type { DbClient } from "../connection.js";
import type { TestReport } from "../tools/plpgsql/test.js";
import { hashContent, type PreparedPlxModule, preparePlxModule, writePreparedBuildFiles } from "./plx-builder.js";
import { loadManifest, type ModuleManifest } from "./resolver.js";

export type ModuleWorkflowArtifactKind = "extension" | "ddl" | "function" | "test" | "grant";

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

export interface ModuleArtifactDiff {
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

export interface ModuleApplyFailure {
  problem: string;
  where: string;
  fixHint?: string;
}

export interface ModuleApplyArtifactResult {
  key: string;
  kind: ModuleWorkflowArtifactKind;
  name: string;
  action: "applied" | "unchanged";
  warning?: string;
}

export interface ModuleApplyExecutionResult {
  ok: boolean;
  diff: ModuleArtifactDiff;
  plan: ModuleWorkflowArtifact[];
  results: ModuleApplyArtifactResult[];
  warnings: string[];
  obsolete: AppliedArtifactState[];
  buildFiles: string[];
  testSchema?: string;
  testReport?: TestReport | null;
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
  try {
    const { rows } = await client.query<{
      artifact_key: string;
      artifact_kind: ModuleWorkflowArtifactKind;
      artifact_name: string;
      artifact_hash: string;
      artifact_file: string | null;
      applied_at: string;
    }>(
      `SELECT artifact_key, artifact_kind, artifact_name, artifact_hash, artifact_file, applied_at::text
         FROM workbench.applied_module_artifact
        WHERE module_name = $1`,
      [moduleName],
    );

    const states = new Map<string, AppliedArtifactState>();
    for (const row of rows) {
      states.set(row.artifact_key, {
        key: row.artifact_key,
        kind: row.artifact_kind,
        name: row.artifact_name,
        hash: row.artifact_hash,
        file: row.artifact_file ?? undefined,
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

export async function applyModuleIncremental(
  client: DbClient,
  workflow: PreparedModuleWorkflow,
  runTests: (client: DbClient, testSchema: string, pattern?: string) => Promise<TestReport | null>,
): Promise<ModuleApplyExecutionResult> {
  const buildFiles = await syncModuleBuildFiles(workflow);
  await ensureApplyTrackingTable(client);

  const applied = await readAppliedArtifacts(client, workflow.manifest.name);
  const diff = diffModuleArtifacts(workflow.artifacts, applied.states);
  if (diff.changed.length === 0) {
    return {
      ok: true,
      diff,
      plan: [],
      obsolete: diff.obsolete,
      buildFiles,
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
      diff,
      plan: [],
      obsolete: diff.obsolete,
      buildFiles,
      results: [],
      warnings: diff.obsolete.map((state) => `obsolete tracked artifact: ${state.kind} ${state.name}`),
      failure: toApplyFailure(error, "pgm_module_apply.ordering"),
    };
  }
  const results: ModuleApplyArtifactResult[] = [];
  const warnings: string[] = [];

  await client.query("BEGIN");
  try {
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

      await client.query(
        `INSERT INTO workbench.applied_module_artifact
           (module_name, artifact_key, artifact_kind, artifact_name, artifact_file, artifact_hash, applied_at)
         VALUES ($1, $2, $3, $4, $5, $6, now())
         ON CONFLICT (module_name, artifact_key)
         DO UPDATE SET
           artifact_kind = EXCLUDED.artifact_kind,
           artifact_name = EXCLUDED.artifact_name,
           artifact_file = EXCLUDED.artifact_file,
           artifact_hash = EXCLUDED.artifact_hash,
           applied_at = now()`,
        [workflow.manifest.name, artifact.key, artifact.kind, artifact.name, artifact.file ?? null, artifact.hash],
      );
    }

    const testSchema = workflow.manifest.schemas.public ? `${workflow.manifest.schemas.public}_ut` : undefined;
    const testReport = testSchema ? await runTests(client, testSchema) : null;
    if (testReport && testReport.failed > 0) {
      await client.query("ROLLBACK");
      return {
        ok: false,
        diff,
        plan: ordered,
        obsolete: diff.obsolete,
        buildFiles,
        results,
        warnings,
        testSchema,
        testReport,
        failure: {
          problem: `${testReport.failed} module test(s) failed`,
          where: testSchema ?? `${workflow.manifest.name}_ut`,
          fixHint: `Fix failing pgTAP tests in ${testSchema} before retrying apply.`,
        },
      };
    }

    await client.query("COMMIT");
    await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});

    return {
      ok: true,
      diff,
      plan: ordered,
      obsolete: diff.obsolete,
      buildFiles,
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
      testSchema,
      testReport,
    };
  } catch (error: unknown) {
    await client.query("ROLLBACK").catch(() => {});
    return {
      ok: false,
      diff,
      plan: ordered,
      obsolete: diff.obsolete,
      buildFiles,
      results,
      warnings,
      failure: toApplyFailure(error),
    };
  }
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
    const content = manifest.extensions.map((ext) => `CREATE EXTENSION IF NOT EXISTS ${qi(ext)};`).join("\n");
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
      grantStatements.push(`GRANT USAGE ON SCHEMA ${qi(schema)} TO ${qi(role)};`);
      grantStatements.push(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${qi(schema)} TO ${qi(role)};`);
      grantStatements.push(`GRANT SELECT ON ALL TABLES IN SCHEMA ${qi(schema)} TO ${qi(role)};`);
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

async function ensureApplyTrackingTable(client: DbClient): Promise<void> {
  await client.query(`CREATE SCHEMA IF NOT EXISTS workbench`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.applied_module_artifact (
      module_name text NOT NULL,
      artifact_key text NOT NULL,
      artifact_kind text NOT NULL,
      artifact_name text NOT NULL,
      artifact_file text,
      artifact_hash text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (module_name, artifact_key)
    )
  `);
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

  const { rows: langRows } = await client.query<{ lang: string }>(
    `SELECT l.lanname AS lang
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       JOIN pg_language l ON l.oid = p.prolang
      WHERE n.nspname = $1 AND p.proname = $2
      ORDER BY p.oid
      LIMIT 1`,
    [schema, name],
  );
  if (langRows[0]?.lang !== "plpgsql") return undefined;

  try {
    await client.query("SAVEPOINT module_plpgsql_check");
    const check = await client.query<{
      lineno: number;
      message: string;
      hint: string | null;
      level: string;
      statement: string | null;
    }>(`SELECT lineno, message, hint, level, statement FROM plpgsql_check_function_tb($1)`, [`${schema}.${name}`]);
    await client.query("RELEASE SAVEPOINT module_plpgsql_check");

    const errors = check.rows.filter((row) => row.level === "error");
    if (errors.length > 0) {
      const first = errors[0];
      if (!first) throw new Error(`plpgsql_check returned an empty error set for ${schema}.${name}`);
      const statement = first.statement ? ` statement: ${first.statement}` : "";
      const hint = first.hint ? ` fix_hint: ${first.hint}` : "";
      throw new Error(`plpgsql_check ${schema}.${name} line ${first.lineno}: ${first.message}${statement}${hint}`);
    }

    const warning = check.rows.find((row) => row.level !== "error");
    if (!warning) return replacementWarning;
    const checkWarning = `plpgsql_check ${schema}.${name} line ${warning.lineno}: ${warning.message}`;
    return replacementWarning ? `${replacementWarning}; ${checkWarning}` : checkWarning;
  } catch (error: unknown) {
    await client.query("ROLLBACK TO SAVEPOINT module_plpgsql_check").catch(() => {});
    const code = (error as { code?: string }).code;
    if (code === "42883" || code === "0A000") return replacementWarning;
    throw error;
  }
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
      ? `DROP FUNCTION IF EXISTS ${qi(schema)}.${qi(name)}(${identityArgs})`
      : `DROP FUNCTION IF EXISTS ${qi(schema)}.${qi(name)}()`;
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

function toApplyFailure(error: unknown, where = "pgm_module_apply"): ModuleApplyFailure {
  const message = error instanceof Error ? error.message : String(error);
  return {
    problem: message,
    where,
    fixHint:
      where === "pgm_module_apply.ordering"
        ? "Break the artifact dependency cycle or split the module so artifacts can be applied in a deterministic order."
        : undefined,
  };
}

function qi(id: string): string {
  return `"${id.replace(/"/g, '""')}"`;
}
