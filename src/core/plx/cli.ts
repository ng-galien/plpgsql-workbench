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
  .option("--stdout", "Print to stdout instead of writing a file")
  .option("--no-validate", "Skip PG parser validation")
  .action(async (file: string, opts: { output?: string; stdout?: boolean; validate?: boolean }) => {
    const source = await readPlx(file);
    const result = opts.validate === false ? compile(source) : await compileAndValidate(source);
    reportErrors(result);

    for (const w of result.warnings) console.error(`  WARN   ${w.functionName}: ${w.message}`);

    if (opts.stdout) {
      process.stdout.write(result.sql + "\n");
    } else {
      const outPath = opts.output ?? file.replace(/\.plx$/, ".sql");
      await fs.writeFile(outPath, result.sql + "\n", "utf-8");
      console.log(`  BUILD  ${path.basename(file)} -> ${path.basename(outPath)} (${result.functionCount} functions)`);
    }
  });

program
  .command("check <file>")
  .description("Check a .plx file for errors and validate generated SQL")
  .option("--no-validate", "Skip PG parser validation")
  .action(async (file: string, opts: { validate?: boolean }) => {
    const source = await readPlx(file);
    const result = opts.validate === false ? compile(source) : await compileAndValidate(source);
    reportErrors(result);

    for (const w of result.warnings) console.error(`  WARN   ${w.functionName}: ${w.message}`);

    const status = result.warnings.length > 0 ? "with warnings" : "no errors";
    console.log(`  OK     ${path.basename(file)} (${result.functionCount} functions, ${status})`);
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
