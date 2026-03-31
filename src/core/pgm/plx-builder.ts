import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { type CompileResult, type CompileWarning, compileModule, compileModuleAndValidate } from "../plx/compiler.js";
import { loadPlxModule } from "../plx/module-loader.js";
import type { ModuleManifest } from "./resolver.js";

export interface PlxBuildResult {
  files: string[];
  warnings: string[];
}

export interface PlxPreparedArtifact {
  key: string;
  kind: "ddl" | "function" | "test";
  name: string;
  file?: string;
  content: string;
  hash: string;
}

export interface PreparedPlxModule {
  entry: string;
  files: string[];
  warnings: string[];
  outputs: {
    ddl?: { file?: string; content: string; hash: string };
    func?: { file?: string; content: string; hash: string };
    test?: { file?: string; content: string; hash: string };
  };
  artifacts: PlxPreparedArtifact[];
}

export async function buildPlxModule(
  modulesDir: string,
  manifest: ModuleManifest,
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
  manifest: ModuleManifest,
  options: { validate?: boolean } = {},
): Promise<PreparedPlxModule> {
  const entry = manifest.plx?.entry;
  if (!entry) {
    return {
      entry: "",
      files: [],
      warnings: [],
      outputs: {},
      artifacts: [],
    };
  }

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

  // Always compile without validate first to preserve _blocks/_artifact for artifacts.
  // Then validate separately if requested — validation only adds warnings.
  const result = compileModule(loaded.module);

  if (result.errors.length > 0) {
    const formatted = result.errors
      .map((error) => `${error.code} ${error.message} (${error.phase}:${error.line}:${error.col})`)
      .join("; ");
    throw new Error(`PLX build failed for module '${manifest.name}': ${formatted}`);
  }

  // Collect artifacts before validation (which deletes _blocks/_artifact)
  const targets = resolveTargets(manifest);
  const ddlContent = buildGeneratedDdl(manifest, result.ddlSql);
  const ddlHash = ddlContent ? hashContent(ddlContent) : undefined;
  const artifacts = collectPreparedArtifacts(result, targets, ddlContent, ddlHash);

  // Validate after artifact collection if requested
  if (options.validate !== false) {
    const validated = await compileModuleAndValidate(loaded.module);
    result.warnings = validated.warnings;
  }

  return {
    entry,
    files: loaded.files,
    warnings: result.warnings.map(formatWarning),
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

function resolveTargets(manifest: ModuleManifest): {
  ddl?: string;
  func?: string;
  test?: string;
} {
  const sqlFiles = manifest.sql ?? [];
  return {
    ddl: sqlFiles.find((file) => isPrimaryDdl(file)),
    func: sqlFiles.find((file) => isPrimaryFunc(file)),
    test: sqlFiles.find((file) => isUnitTestFunc(file)),
  };
}

function isPrimaryDdl(file: string): boolean {
  return file.endsWith(".ddl.sql") && !file.includes("_qa.") && !file.includes("_ut.") && !file.includes("_it.");
}

function isPrimaryFunc(file: string): boolean {
  return file.endsWith(".func.sql") && !file.includes("_qa.") && !file.includes("_ut.") && !file.includes("_it.");
}

function isUnitTestFunc(file: string): boolean {
  return file.endsWith("_ut.func.sql");
}

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
  result: CompileResult,
  targets: ReturnType<typeof resolveTargets>,
  ddlContent?: string,
  precomputedDdlHash?: string,
): PlxPreparedArtifact[] {
  const artifacts: PlxPreparedArtifact[] = [];

  if (ddlContent) {
    artifacts.push({
      key: "ddl",
      kind: "ddl",
      name: targets.ddl ?? "ddl",
      file: targets.ddl,
      content: ddlContent,
      hash: precomputedDdlHash ?? hashContent(ddlContent),
    });
  }

  const testFunctions = new Set(result._artifact?.testFunctions.map((fn) => `${fn.schema}.${fn.name}`) ?? []);
  for (const block of result._blocks ?? []) {
    const kind = testFunctions.has(block.functionName) ? "test" : "function";
    artifacts.push({
      key: `${kind}:${block.functionName}`,
      kind,
      name: block.functionName,
      file: kind === "test" ? targets.test : targets.func,
      content: block.sql,
      hash: hashContent(block.sql),
    });
  }

  return artifacts;
}

export function hashContent(content: string): string {
  return crypto.createHash("sha256").update(content.trimEnd()).digest("hex").slice(0, 16);
}

function buildGeneratedDdl(manifest: ModuleManifest, compilerDdl?: string): string | undefined {
  const parts: string[] = [];
  const { public: pub, private: priv, qa } = manifest.schemas;

  if (pub) {
    parts.push(`CREATE SCHEMA IF NOT EXISTS "${pub.replace(/"/g, '""')}";`);
    parts.push(`CREATE SCHEMA IF NOT EXISTS "${`${pub}_ut`.replace(/"/g, '""')}";`);
  }
  if (priv) {
    parts.push(`CREATE SCHEMA IF NOT EXISTS "${priv.replace(/"/g, '""')}";`);
  }
  if (qa) {
    parts.push(`CREATE SCHEMA IF NOT EXISTS "${qa.replace(/"/g, '""')}";`);
  }
  if (compilerDdl?.trim()) {
    parts.push(compilerDdl.trim());
  }

  if (parts.length === 0) return undefined;
  return parts.join("\n\n");
}

function formatWarning(warning: CompileWarning): string {
  return `${warning.code} ${warning.functionName}: ${warning.message} (${warning.line}:${warning.col})`;
}
