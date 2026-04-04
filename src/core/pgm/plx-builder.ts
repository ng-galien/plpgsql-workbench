import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { type CompileWarning, compileModuleAndValidate, compileModuleBundle } from "../plx/compiler.js";
import { collectCalls, resolveCallTarget } from "../plx/composition.js";
import { buildModuleContract, type ModuleContract } from "../plx/contract.js";
import { loadPlxManifest, type PlxModuleManifest, plxBuildTargets } from "../plx/manifest.js";
import { loadPlxModule } from "../plx/module-loader.js";
import { loadManifest } from "./resolver.js";

interface PlxBuildResult {
  files: string[];
  warnings: string[];
}

interface PlxPreparedArtifact {
  key: string;
  kind: "ddl" | "function" | "test";
  name: string;
  file?: string;
  content: string;
  hash: string;
  dependsOn: string[];
}

export interface PreparedPlxModule {
  entry: string;
  files: string[];
  warnings: string[];
  contract?: ModuleContract;
  outputs: {
    ddl?: { file?: string; content: string; hash: string };
    func?: { file?: string; content: string; hash: string };
    test?: { file?: string; content: string; hash: string };
  };
  artifacts: PlxPreparedArtifact[];
}

export async function buildPlxModule(
  modulesDir: string,
  manifest: PlxModuleManifest,
  options: { validate?: boolean } = {},
): Promise<PlxBuildResult> {
  const prepared = await preparePlxModule(modulesDir, manifest, options);
  const moduleDir = path.join(modulesDir, manifest.name);
  const written = await writePreparedBuildFiles(moduleDir, prepared, manifest.name);

  return {
    files: written,
    warnings: prepared.warnings,
  };
}

export async function preparePlxModule(
  modulesDir: string,
  manifest: PlxModuleManifest,
  options: { validate?: boolean } = {},
): Promise<PreparedPlxModule> {
  const entry = manifest.plx.entry;
  const moduleDir = path.join(modulesDir, manifest.name);
  const entryPath = path.join(moduleDir, entry);
  await fs.access(entryPath);

  const loaded = await loadPlxModule(entryPath);
  if (!loaded.module) {
    const formatted = loaded.errors
      .map((error) => `${error.code} ${error.message} (${error.file ?? "plx"}:${error.line}:${error.col})`)
      .join("; ");
    throw new Error(`PLX build failed for module '${manifest.name}': ${formatted}`);
  }

  const contract = buildModuleContract(loaded.module);
  const dependencyContracts = await loadDependencyContracts(modulesDir, manifest);
  const bundle = compileModuleBundle(loaded.module, { dependencyContracts });
  let { result } = bundle;

  if (result.errors.length > 0) {
    const formatted = result.errors
      .map((error) => `${error.code} ${error.message} (${error.phase}:${error.line}:${error.col})`)
      .join("; ");
    throw new Error(`PLX build failed for module '${manifest.name}': ${formatted}`);
  }

  const targets = plxBuildTargets(manifest.name);
  const extraSchemaArtifacts = buildSupplementalSchemaArtifacts(bundle, manifest);
  const ddlContent = buildGeneratedDdl(bundle, extraSchemaArtifacts);
  const ddlHash = ddlContent ? hashContent(ddlContent) : undefined;
  const artifacts = collectPreparedArtifacts(bundle, targets, extraSchemaArtifacts);

  // Load seed artifact if declared
  if (manifest.plx.seed) {
    const seedPath = path.join(moduleDir, manifest.plx.seed);
    const seedContent = await fs.readFile(seedPath, "utf-8");
    artifacts.push({
      key: "seed",
      kind: "ddl",
      name: `${manifest.name}.seed`,
      file: manifest.plx.seed,
      content: seedContent,
      hash: hashContent(seedContent),
      dependsOn: [],
    });
  }

  // Validate if requested — validation only adds warnings
  if (options.validate !== false) {
    result = await compileModuleAndValidate(loaded.module, { dependencyContracts });
  }

  return {
    entry,
    files: loaded.files,
    warnings: result.warnings.map(formatWarning),
    contract,
    outputs: {
      ddl: ddlContent && ddlHash ? { file: targets.ddl, content: ddlContent, hash: ddlHash } : undefined,
      func: result.sql.trim() ? { file: targets.func, content: result.sql, hash: hashContent(result.sql) } : undefined,
      test: result.testSql?.trim()
        ? { file: targets.test, content: result.testSql, hash: hashContent(result.testSql) }
        : undefined,
    },
    artifacts,
  };
}

async function loadDependencyContracts(
  modulesDir: string,
  manifest: PlxModuleManifest,
): Promise<Map<string, ModuleContract>> {
  const contracts = new Map<string, ModuleContract>();
  for (const dep of manifest.dependencies ?? []) {
    // Dependencies may be PLX or legacy — use loadManifest which handles both
    const dependency = await loadManifest(modulesDir, dep);
    if (dependency.plxContract) contracts.set(dep, dependency.plxContract);
  }
  return contracts;
}

export async function writePreparedBuildFiles(
  moduleDir: string,
  prepared: PreparedPlxModule,
  moduleName = path.basename(moduleDir),
): Promise<string[]> {
  const written: string[] = [];

  if (prepared.outputs.ddl) {
    if (!prepared.outputs.ddl.file) {
      throw new Error(`PLX module '${moduleName}' generated DDL but module.json has no primary .ddl.sql target`);
    }
    await writeModuleFile(moduleDir, prepared.outputs.ddl.file, prepared.outputs.ddl.content);
    written.push(prepared.outputs.ddl.file);
  }

  if (prepared.outputs.func?.content.trim()) {
    if (!prepared.outputs.func.file) {
      throw new Error(`PLX module '${moduleName}' generated functions but module.json has no primary .func.sql target`);
    }
    await writeModuleFile(moduleDir, prepared.outputs.func.file, prepared.outputs.func.content);
    written.push(prepared.outputs.func.file);
  }

  if (prepared.outputs.test?.content.trim()) {
    if (!prepared.outputs.test.file) {
      throw new Error(`PLX module '${moduleName}' generated tests but module.json has no _ut.func.sql target`);
    }
    await writeModuleFile(moduleDir, prepared.outputs.test.file, prepared.outputs.test.content);
    written.push(prepared.outputs.test.file);
  }

  return written;
}

// resolveTargets removed — use plxBuildTargets() from manifest.ts

async function writeModuleFile(moduleDir: string, relativePath: string, content: string): Promise<void> {
  const outputPath = path.join(moduleDir, relativePath);
  const expected = `${content}\n`;
  try {
    const current = await fs.readFile(outputPath, "utf-8");
    if (current === expected) return;
  } catch {
    // Fall through: file is missing or unreadable, write a fresh copy.
  }
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, expected, "utf-8");
}

function collectPreparedArtifacts(
  bundle: ReturnType<typeof compileModuleBundle>,
  targets: ReturnType<typeof plxBuildTargets>,
  extraDdlArtifacts: PlxPreparedArtifact[] = [],
): PlxPreparedArtifact[] {
  const artifacts: PlxPreparedArtifact[] = [...extraDdlArtifacts];
  const dependencyMap = collectArtifactDependencies(bundle);

  for (const ddlArtifact of bundle.artifact.ddlArtifacts) {
    artifacts.push({
      key: ddlArtifact.key,
      kind: "ddl",
      name: ddlArtifact.name,
      file: targets.ddl,
      content: ddlArtifact.sql,
      hash: hashContent(ddlArtifact.sql),
      dependsOn: ddlArtifact.dependsOn,
    });
  }

  const testFunctions = new Set(bundle.artifact.testFunctions.map((fn) => `${fn.schema}.${fn.name}`));
  for (const block of bundle.blocks) {
    const kind = testFunctions.has(block.functionName) ? "test" : "function";
    const key = `${kind}:${block.functionName}`;
    artifacts.push({
      key,
      kind,
      name: block.functionName,
      file: kind === "test" ? targets.test : targets.func,
      content: block.sql,
      hash: hashContent(block.sql),
      dependsOn: dependencyMap.get(key) ?? [],
    });
  }

  return artifacts;
}

function collectArtifactDependencies(bundle: ReturnType<typeof compileModuleBundle>): Map<string, string[]> {
  const dependencies = new Map<string, string[]>();
  const { artifact } = bundle;

  const aliases = artifact.aliases;
  const functionKeys = new Map<string, string>();
  const bareFunctionKeys = new Map<string, string | null>();

  for (const fn of artifact.functions) {
    const qualifiedName = `${fn.schema}.${fn.name}`;
    const artifactKey = `function:${qualifiedName}`;
    functionKeys.set(qualifiedName, artifactKey);

    const existing = bareFunctionKeys.get(fn.name);
    if (existing === undefined) bareFunctionKeys.set(fn.name, artifactKey);
    else if (existing !== artifactKey) bareFunctionKeys.set(fn.name, null);
  }

  const resolveLocalFunctionKey = (targetName: string, currentSchema: string): string | undefined => {
    const resolved = resolveCallTarget(targetName, aliases);
    if (resolved.includes(".")) return functionKeys.get(resolved);

    const local = functionKeys.get(`${currentSchema}.${resolved}`);
    if (local) return local;

    const bare = bareFunctionKeys.get(resolved);
    return bare && bare !== null ? bare : undefined;
  };

  for (const fn of artifact.functions) {
    const artifactKey = `function:${fn.schema}.${fn.name}`;
    const dependsOn = new Set<string>();
    for (const call of collectCalls(fn.body)) {
      const dependencyKey = resolveLocalFunctionKey(call.name, fn.schema);
      if (dependencyKey && dependencyKey !== artifactKey) dependsOn.add(dependencyKey);
    }
    dependencies.set(artifactKey, [...dependsOn].sort());
  }

  for (const fn of artifact.testFunctions) {
    const artifactKey = `test:${fn.schema}.${fn.name}`;
    const dependsOn = new Set<string>();
    for (const call of collectCalls(fn.body)) {
      const dependencyKey = resolveLocalFunctionKey(call.name, fn.schema);
      if (dependencyKey) dependsOn.add(dependencyKey);
    }
    dependencies.set(artifactKey, [...dependsOn].sort());
  }

  return dependencies;
}

export function hashContent(content: string): string {
  return crypto.createHash("sha256").update(content.trimEnd()).digest("hex").slice(0, 16);
}

function buildGeneratedDdl(
  bundle: ReturnType<typeof compileModuleBundle>,
  extraDdlArtifacts: ReadonlyArray<Pick<PlxPreparedArtifact, "content">> = [],
): string | undefined {
  const parts: string[] = [];
  for (const artifact of bundle.artifact.ddlArtifacts) {
    parts.push(artifact.sql.trim());
  }
  for (const artifact of extraDdlArtifacts) {
    parts.push(artifact.content.trim());
  }
  if (parts.length === 0) return undefined;
  return parts.join("\n\n");
}

function buildSupplementalSchemaArtifacts(
  bundle: ReturnType<typeof compileModuleBundle>,
  manifest: PlxModuleManifest,
): PlxPreparedArtifact[] {
  const existing = new Set(bundle.artifact.ddlArtifacts.map((artifact) => artifact.key));
  const targets = plxBuildTargets(manifest.name);
  const schemas = [manifest.private].filter((value): value is string => Boolean(value));

  return schemas
    .filter((schema) => !existing.has(`ddl:schema:${schema}`))
    .sort()
    .map((schema) => ({
      key: `ddl:schema:${schema}`,
      kind: "ddl" as const,
      name: `${schema}.schema`,
      file: targets.ddl,
      content: `CREATE SCHEMA IF NOT EXISTS "${schema.replace(/"/g, '""')}";`,
      hash: hashContent(`CREATE SCHEMA IF NOT EXISTS "${schema.replace(/"/g, '""')}";`),
      dependsOn: [],
    }));
}

function formatWarning(warning: CompileWarning): string {
  return `${warning.code} ${warning.functionName}: ${warning.message} (${warning.line}:${warning.col})`;
}
