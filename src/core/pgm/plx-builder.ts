import fs from "node:fs/promises";
import path from "node:path";
import { type CompileWarning, compile, compileAndValidate } from "../plx/compiler.js";
import type { ModuleManifest } from "./resolver.js";

export interface PlxBuildResult {
  files: string[];
  warnings: string[];
}

export async function buildPlxModule(
  modulesDir: string,
  manifest: ModuleManifest,
  options: { validate?: boolean } = {},
): Promise<PlxBuildResult> {
  const entry = manifest.plx?.entry;
  if (!entry) return { files: [], warnings: [] };

  const moduleDir = path.join(modulesDir, manifest.name);
  const entryPath = path.join(moduleDir, entry);
  const source = await fs.readFile(entryPath, "utf-8");
  const result = options.validate === false ? compile(source) : await compileAndValidate(source);

  if (result.errors.length > 0) {
    const formatted = result.errors
      .map((error) => `${error.code} ${error.message} (${error.phase}:${error.line}:${error.col})`)
      .join("; ");
    throw new Error(`PLX build failed for module '${manifest.name}': ${formatted}`);
  }

  const targets = resolveTargets(manifest);
  const written: string[] = [];

  if (result.ddlSql) {
    if (!targets.ddl) {
      throw new Error(`PLX module '${manifest.name}' generated DDL but module.json has no primary .ddl.sql target`);
    }
    await writeModuleFile(moduleDir, targets.ddl, result.ddlSql);
    written.push(targets.ddl);
  }

  if (result.sql.trim()) {
    if (!targets.func) {
      throw new Error(
        `PLX module '${manifest.name}' generated functions but module.json has no primary .func.sql target`,
      );
    }
    await writeModuleFile(moduleDir, targets.func, result.sql);
    written.push(targets.func);
  }

  if (result.testSql?.trim()) {
    if (!targets.test) {
      throw new Error(`PLX module '${manifest.name}' generated tests but module.json has no _ut.func.sql target`);
    }
    await writeModuleFile(moduleDir, targets.test, result.testSql);
    written.push(targets.test);
  }

  return {
    files: written,
    warnings: result.warnings.map(formatWarning),
  };
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
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${content}\n`, "utf-8");
}

function formatWarning(warning: CompileWarning): string {
  return `${warning.code} ${warning.functionName}: ${warning.message} (${warning.line}:${warning.col})`;
}
