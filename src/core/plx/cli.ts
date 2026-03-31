#!/usr/bin/env node --max-old-space-size=8192

import fs from "node:fs/promises";
import path from "node:path";
import { Command } from "commander";
import { type CompileResult, compile, compileAndValidate } from "./compiler.js";

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
      const source = await readPlx(file);
      const result = opts.validate === false ? compile(source) : await compileAndValidate(source);
      reportErrors(result);

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
  .option("--no-validate", "Skip PG parser validation")
  .action(async (file: string, opts: { validate?: boolean }) => {
    const source = await readPlx(file);
    const result = opts.validate === false ? compile(source) : await compileAndValidate(source);
    reportErrors(result);

    for (const w of result.warnings) console.error(formatWarning(w));

    const status = result.warnings.length > 0 ? "with warnings" : "no errors";
    const testInfo = result.testCount ? `, ${result.testCount} tests` : "";
    console.log(`  OK     ${path.basename(file)} (${result.functionCount} functions${testInfo}, ${status})`);
  });

program.parse();

function reportErrors(result: CompileResult): void {
  if (result.errors.length === 0) return;
  for (const err of result.errors) {
    console.error(`  ERROR  ${err.phase}:${err.line}:${err.col} ${err.message}`);
  }
  process.exit(1);
}

async function readPlx(file: string): Promise<string> {
  try {
    return await fs.readFile(file, "utf-8");
  } catch {
    console.error(`  ERROR  cannot read file: ${file}`);
    process.exit(1);
  }
}

function deriveArtifactPath(baseOutput: string, kind: "ddl" | "test"): string {
  return baseOutput.endsWith(".sql") ? baseOutput.replace(/\.sql$/, `.${kind}.sql`) : `${baseOutput}.${kind}.sql`;
}

function formatWarning(warning: CompileResult["warnings"][number]): string {
  const loc = warning.line !== undefined && warning.col !== undefined ? `${warning.line}:${warning.col} ` : "";
  return `  WARN   ${warning.functionName}: ${loc}${warning.message}`;
}
