#!/usr/bin/env node --max-old-space-size=8192

import fs from "node:fs/promises";
import path from "node:path";
import { Command } from "commander";
import { type CompileResult, compileModule, compileModuleAndValidate } from "./compiler.js";
import { type CompositionResult, composeModules } from "./composition.js";
import { loadPlxModule } from "./module-loader.js";

const program = new Command();

program.name("plx").description("PLX language compiler — compiles .plx to PL/pgSQL").version("0.1.0");

program
  .command("build <file>")
  .description("Compile a .plx file to PL/pgSQL .sql")
  .option("-o, --output <file>", "Output file (default: same name with .sql extension)")
  .option("--split", "Write functions, DDL and tests to separate files")
  .option("--ddl-output <file>", "Write generated DDL to a separate file")
  .option("--test-output <file>", "Write generated test functions to a separate file")
  .option("--stdout", "Print to stdout instead of writing a file")
  .option("--no-validate", "Skip PG parser validation")
  .action(
    async (
      file: string,
      opts: {
        output?: string;
        split?: boolean;
        ddlOutput?: string;
        testOutput?: string;
        stdout?: boolean;
        validate?: boolean;
      },
    ) => {
      const loaded = await loadModuleOrExit(file, false);
      if (!loaded) return;
      const result =
        opts.validate === false ? compileModule(loaded.module) : await compileModuleAndValidate(loaded.module);
      reportDiagnosticErrors(result.errors);

      for (const w of result.warnings) console.error(formatWarning(w));

      const allSql = [result.sql, result.testSql].filter(Boolean).join("\n\n");
      const testInfo = result.testCount ? `, ${result.testCount} tests` : "";

      if (opts.stdout) {
        process.stdout.write(`${allSql}\n`);
      } else {
        const outPath = opts.output ?? file.replace(/\.plx$/, ".sql");
        const separated = opts.split || Boolean(opts.ddlOutput) || Boolean(opts.testOutput);
        const written: string[] = [];

        if (separated) {
          if (result.sql.trim()) {
            await fs.writeFile(outPath, `${result.sql}\n`, "utf-8");
            written.push(path.basename(outPath));
          }

          if (result.ddlSql) {
            const ddlPath = opts.ddlOutput ?? deriveArtifactPath(outPath, "ddl");
            await fs.writeFile(ddlPath, `${result.ddlSql}\n`, "utf-8");
            written.push(path.basename(ddlPath));
          }

          if (result.testSql) {
            const testPath = opts.testOutput ?? deriveArtifactPath(outPath, "test");
            await fs.writeFile(testPath, `${result.testSql}\n`, "utf-8");
            written.push(path.basename(testPath));
          }
        } else {
          await fs.writeFile(outPath, `${allSql}\n`, "utf-8");
          written.push(path.basename(outPath));
        }

        console.log(
          `  BUILD  ${path.basename(file)} -> ${written.join(", ")} (${result.functionCount} functions${testInfo})`,
        );
      }
    },
  );

program
  .command("check <file>")
  .description("Check a .plx file for errors and validate generated SQL")
  .option("--json", "Print machine-readable diagnostics")
  .option("--no-validate", "Skip PG parser validation")
  .action(async (file: string, opts: { json?: boolean; validate?: boolean }) => {
    const loaded = await loadModuleOrExit(file, Boolean(opts.json));
    if (!loaded) return;
    const result =
      opts.validate === false ? compileModule(loaded.module) : await compileModuleAndValidate(loaded.module);
    if (opts.json) {
      process.stdout.write(`${JSON.stringify(buildCheckPayload(file, result), null, 2)}\n`);
      process.exit(result.errors.length === 0 ? 0 : 1);
    }

    reportDiagnosticErrors(result.errors);

    for (const w of result.warnings) console.error(formatWarning(w));

    const status = result.warnings.length > 0 ? "with warnings" : "no errors";
    const testInfo = result.testCount ? `, ${result.testCount} tests` : "";
    console.log(`  OK     ${path.basename(file)} (${result.functionCount} functions${testInfo}, ${status})`);
  });

program
  .command("compose <files...>")
  .description("Check a composed set of PLX modules and verify cross-module contracts")
  .option("--json", "Print machine-readable diagnostics")
  .option("--no-validate", "Skip PG parser validation for individual modules")
  .action(async (files: string[], opts: { json?: boolean; validate?: boolean }) => {
    const loadedInputs: Array<{
      file: string;
      module: NonNullable<Awaited<ReturnType<typeof loadPlxModule>>["module"]>;
    }> = [];
    for (const file of files) {
      const loaded = await loadModuleOrExit(file, Boolean(opts.json));
      if (!loaded) return;
      loadedInputs.push({ file, module: loaded.module });
    }

    const result = await composeModules(loadedInputs, { validate: opts.validate });
    if (opts.json) {
      process.stdout.write(
        `${JSON.stringify(
          buildComposePayload(
            loadedInputs.map((input) => input.file),
            result,
          ),
          null,
          2,
        )}\n`,
      );
      process.exit(result.errors.length === 0 ? 0 : 1);
    }

    reportDiagnosticErrors(result.errors);

    for (const w of result.warnings) console.error(formatWarning(w));

    const moduleCount = result.modules.filter((module) => module.moduleName).length;
    const status = result.warnings.length > 0 ? "with warnings" : "no errors";
    console.log(`  OK     composition (${moduleCount} modules, ${status})`);
  });

program.parse();

function reportDiagnosticErrors(errors: CompileResult["errors"]): void {
  if (errors.length === 0) return;
  for (const err of errors) console.error(formatError(err));
  process.exit(1);
}

async function loadModuleOrExit(
  file: string,
  json: boolean,
): Promise<{ module: NonNullable<Awaited<ReturnType<typeof loadPlxModule>>["module"]> } | undefined> {
  const loaded = await loadPlxModule(file);
  if (!loaded.module) {
    if (json) {
      process.stdout.write(
        `${JSON.stringify(
          {
            file: path.resolve(file),
            ok: false,
            functionCount: 0,
            entityCount: 0,
            testCount: 0,
            warnings: [],
            errors: loaded.errors,
          },
          null,
          2,
        )}\n`,
      );
    } else {
      reportDiagnosticErrors(loaded.errors);
    }
    process.exit(1);
  }
  return { module: loaded.module };
}

function deriveArtifactPath(baseOutput: string, kind: "ddl" | "test"): string {
  return baseOutput.endsWith(".sql") ? baseOutput.replace(/\.sql$/, `.${kind}.sql`) : `${baseOutput}.${kind}.sql`;
}

function buildCheckPayload(file: string, result: CompileResult): object {
  return {
    file: path.resolve(file),
    ok: result.errors.length === 0,
    functionCount: result.functionCount,
    entityCount: result.entityCount ?? 0,
    testCount: result.testCount ?? 0,
    warnings: result.warnings,
    errors: result.errors,
  };
}

function buildComposePayload(files: string[], result: CompositionResult): object {
  return {
    files: files.map((file) => path.resolve(file)),
    ok: result.errors.length === 0,
    moduleCount: result.modules.filter((module) => module.moduleName).length,
    warnings: result.warnings,
    errors: result.errors,
    modules: result.modules.map((module) => ({
      file: path.resolve(module.file),
      moduleName: module.moduleName,
      functionCount: module.functionCount,
      entityCount: module.entityCount,
      testCount: module.testCount,
      warnings: module.warnings,
      errors: module.errors,
    })),
  };
}

function formatError(error: CompileResult["errors"][number]): string {
  const file = error.file ? `${path.relative(process.cwd(), error.file)}:` : "";
  const loc = `${file}${error.phase}:${error.line}:${error.col}`;
  const hint = error.hint ? `\n         hint: ${error.hint}` : "";
  return `  ERROR  ${loc} [${error.code}] ${error.message}${hint}`;
}

function formatWarning(warning: CompileResult["warnings"][number]): string {
  const file = warning.file ? `${path.relative(process.cwd(), warning.file)}:` : "";
  const loc = warning.line !== undefined && warning.col !== undefined ? `${file}${warning.line}:${warning.col} ` : "";
  const hint = warning.hint ? `\n         hint: ${warning.hint}` : "";
  return `  WARN   ${warning.functionName}: ${loc}[${warning.code}] ${warning.message}${hint}`;
}
