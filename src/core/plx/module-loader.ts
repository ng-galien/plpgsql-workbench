import fs from "node:fs/promises";
import path from "node:path";
import type { I18nBlock, I18nEntry, PlxEntity, PlxFunction, PlxModule } from "./ast.js";
import { type CompileError, createDiagnostic } from "./compiler.js";
import { LexError, tokenize } from "./lexer.js";
import { ParseError } from "./parse-context.js";
import { parse } from "./parser.js";

interface LoadPlxModuleResult {
  errors: CompileError[];
  files: string[];
  module?: PlxModule;
}

export async function loadPlxModule(entryPath: string): Promise<LoadPlxModuleResult> {
  const resolvedEntry = path.resolve(entryPath);
  const rootResult = await parsePlxFile(resolvedEntry, "module");
  if (!rootResult.module) return { errors: rootResult.errors, files: [resolvedEntry] };

  const root = rootResult.module;
  const errors: CompileError[] = [...rootResult.errors];
  const files = [resolvedEntry];
  const i18nPath = resolvedEntry.replace(/\.plx$/i, ".i18n");
  const i18nResult = await parseOptionalI18nFile(i18nPath);
  errors.push(...i18nResult.errors);
  if (i18nResult.blocks.length > 0) files.push(i18nPath);
  root.i18n.push(...i18nResult.blocks);
  const fragments: PlxModule[] = [];
  const seenIncludes = new Set<string>();

  for (const include of root.includes) {
    const resolvedInclude = path.resolve(path.dirname(resolvedEntry), include.path);
    if (seenIncludes.has(resolvedInclude)) {
      errors.push(
        createDiagnostic(
          "semantic",
          "module.duplicate-include",
          `duplicate include '${include.path}'`,
          include.loc,
          "Keep each included PLX fragment listed once in the module entry file.",
        ),
      );
      continue;
    }
    seenIncludes.add(resolvedInclude);
    files.push(resolvedInclude);

    const fragmentResult = await parsePlxFile(resolvedInclude, "fragment");
    if (!fragmentResult.module) {
      errors.push(...fragmentResult.errors);
      continue;
    }
    errors.push(...fragmentResult.errors);
    fragments.push(fragmentResult.module);
  }

  if (errors.length > 0) return { errors, files };

  const module = mergeModule(root, fragments);
  errors.push(...applyDeclaredExports(module));
  return errors.length > 0 ? { errors, files } : { module, errors: [], files };
}

export function buildModuleFromSource(source: string, file?: string): LoadPlxModuleResult {
  const result = parsePlxSource(source, file, "module");
  if (!result.module) return { errors: result.errors, files: file ? [file] : [] };

  const module = result.module;
  const errors = applyDeclaredExports(module);
  return errors.length > 0 ? { errors, files: file ? [file] : [] } : { module, errors: [], files: file ? [file] : [] };
}

async function parsePlxFile(filePath: string, kind: "module" | "fragment"): Promise<LoadPlxModuleResult> {
  let source: string;
  try {
    source = await fs.readFile(filePath, "utf-8");
  } catch {
    return {
      errors: [
        createDiagnostic(
          "lex",
          "io.read-failed",
          `cannot read file: ${filePath}`,
          { file: filePath, line: 0, col: 0, endLine: 0, endCol: 0 },
          "Check that the file exists and is readable.",
        ),
      ],
      files: [filePath],
    };
  }

  return parsePlxSource(source, filePath, kind);
}

function parsePlxSource(
  source: string,
  filePath: string | undefined,
  kind: "module" | "fragment",
): LoadPlxModuleResult {
  let tokens: ReturnType<typeof tokenize>;
  try {
    tokens = tokenize(source, { file: filePath });
  } catch (error: unknown) {
    return { errors: [toLoadError("lex", error, "lex.invalid-token", filePath)], files: filePath ? [filePath] : [] };
  }

  try {
    const module = parse(tokens, { kind });
    return { module, errors: [], files: filePath ? [filePath] : [] };
  } catch (error: unknown) {
    return {
      errors: [toLoadError("parse", error, "parse.invalid-syntax", filePath)],
      files: filePath ? [filePath] : [],
    };
  }
}

async function parseOptionalI18nFile(filePath: string): Promise<{ blocks: I18nBlock[]; errors: CompileError[] }> {
  let source: string;
  try {
    source = await fs.readFile(filePath, "utf-8");
  } catch (error: unknown) {
    const missing = error instanceof Error && "code" in error && error.code === "ENOENT";
    return missing
      ? { blocks: [], errors: [] }
      : {
          blocks: [],
          errors: [
            createDiagnostic(
              "lex",
              "io.read-failed",
              `cannot read file: ${filePath}`,
              { file: filePath, line: 0, col: 0, endLine: 0, endCol: 0 },
              "Check that the file exists and is readable.",
            ),
          ],
        };
  }

  return parseI18nSource(source, filePath);
}

function parseI18nSource(source: string, filePath: string): { blocks: I18nBlock[]; errors: CompileError[] } {
  const blocks = new Map<string, I18nEntry[]>();
  const errors: CompileError[] = [];
  let currentLang: string | undefined;

  const lines = source.split(/\r?\n/);
  for (let index = 0; index < lines.length; index++) {
    const raw = lines[index] ?? "";
    const lineNo = index + 1;
    const trimmed = raw.trim();
    if (trimmed === "" || trimmed.startsWith("#") || trimmed.startsWith("--")) continue;

    const section = trimmed.match(/^\[([A-Za-z0-9_-]+)\]$/);
    if (section) {
      const lang = section[1];
      if (!lang) continue;
      currentLang = lang;
      if (!blocks.has(lang)) blocks.set(lang, []);
      continue;
    }

    if (!currentLang) {
      errors.push(
        createDiagnostic(
          "parse",
          "parse.i18n-missing-lang-section",
          "i18n entry declared before any [lang] section",
          { file: filePath, line: lineNo, col: 1, endLine: lineNo, endCol: raw.length + 1 },
          "Start the file with a language section like `[fr]`.",
        ),
      );
      continue;
    }

    const eq = raw.indexOf("=");
    if (eq < 0) {
      errors.push(
        createDiagnostic(
          "parse",
          "parse.i18n-invalid-entry",
          "invalid i18n entry",
          { file: filePath, line: lineNo, col: 1, endLine: lineNo, endCol: raw.length + 1 },
          "Use `module.key = Valeur` inside a `[lang]` section.",
        ),
      );
      continue;
    }

    const key = raw.slice(0, eq).trim();
    const value = raw.slice(eq + 1).trim();
    if (!key || !value) {
      errors.push(
        createDiagnostic(
          "parse",
          "parse.i18n-invalid-entry",
          "invalid i18n entry",
          { file: filePath, line: lineNo, col: 1, endLine: lineNo, endCol: raw.length + 1 },
          "Use `module.key = Valeur` with both key and value.",
        ),
      );
      continue;
    }

    if (!/^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$/.test(key)) {
      errors.push(
        createDiagnostic(
          "parse",
          "parse.i18n-invalid-key",
          `invalid i18n key '${key}'`,
          {
            file: filePath,
            line: lineNo,
            col: 1,
            endLine: lineNo,
            endCol: eq + 1,
          },
          "Use dotted keys like `plxdemo.entity_task`.",
        ),
      );
      continue;
    }

    const entries = blocks.get(currentLang) ?? [];
    entries.push({
      key,
      value,
      loc: {
        file: filePath,
        line: lineNo,
        col: 1,
        endLine: lineNo,
        endCol: raw.length + 1,
      },
    });
    blocks.set(currentLang, entries);
  }

  return {
    blocks: [...blocks.entries()].map(([lang, entries]) => ({
      lang,
      entries,
      loc: entries[0]?.loc ?? { file: filePath, line: 1, col: 1, endLine: 1, endCol: 1 },
    })),
    errors,
  };
}

function mergeModule(root: PlxModule, fragments: PlxModule[]): PlxModule {
  return {
    name: root.name,
    moduleLoc: root.moduleLoc,
    depends: [...root.depends],
    exports: [...root.exports],
    includes: [...root.includes],
    imports: [...root.imports, ...fragments.flatMap((fragment) => fragment.imports)],
    i18n: [...root.i18n, ...fragments.flatMap((fragment) => fragment.i18n)],
    traits: [...root.traits, ...fragments.flatMap((fragment) => fragment.traits)],
    entities: [...root.entities, ...fragments.flatMap((fragment) => fragment.entities)],
    functions: [...root.functions, ...fragments.flatMap((fragment) => fragment.functions)],
    subscriptions: [...root.subscriptions, ...fragments.flatMap((fragment) => fragment.subscriptions)],
    tests: [...root.tests, ...fragments.flatMap((fragment) => fragment.tests)],
  };
}

function applyDeclaredExports(module: PlxModule): CompileError[] {
  if (module.exports.length === 0) return [];

  for (const fn of module.functions) fn.visibility = "internal";
  for (const entity of module.entities) {
    entity.visibility = "internal";
    for (const event of entity.events) event.visibility = "internal";
  }

  const functions = new Map<string, PlxFunction>();
  const entities = new Map<string, PlxEntity>();
  for (const fn of module.functions) functions.set(`${fn.schema}.${fn.name}`, fn);
  for (const entity of module.entities) entities.set(`${entity.schema}.${entity.name}`, entity);

  const errors: CompileError[] = [];
  const seen = new Set<string>();

  for (const entry of module.exports) {
    if (seen.has(entry.name)) {
      errors.push(
        createDiagnostic(
          "semantic",
          "module.duplicate-export",
          `duplicate export '${entry.name}'`,
          entry.loc,
          "Keep each exported symbol listed once in the module entry file.",
        ),
      );
      continue;
    }
    seen.add(entry.name);

    const fn = functions.get(entry.name);
    const entity = entities.get(entry.name);
    if (!fn && !entity) {
      errors.push(
        createDiagnostic(
          "semantic",
          "module.unknown-export",
          `module root exports unknown symbol '${entry.name}'`,
          entry.loc,
          "Export a declared function or entity, or remove the stale export entry.",
        ),
      );
      continue;
    }

    if (fn) fn.visibility = "export";
    if (entity) {
      entity.visibility = "export";
      for (const event of entity.events) event.visibility = "export";
    }
  }

  return errors;
}

function toLoadError(
  phase: CompileError["phase"],
  error: unknown,
  fallbackCode: string,
  filePath?: string,
): CompileError {
  if (error instanceof LexError) {
    return createDiagnostic(
      phase,
      error.code ?? fallbackCode,
      error.message,
      {
        file: error.file ?? filePath,
        line: error.line,
        col: error.col,
        endLine: error.endLine,
        endCol: error.endCol,
      },
      error.hint,
    );
  }

  if (error instanceof ParseError) {
    return createDiagnostic(
      phase,
      error.code ?? fallbackCode,
      error.message,
      filePath && !error.loc.file ? { ...error.loc, file: filePath } : error.loc,
      error.hint,
    );
  }

  return createDiagnostic(phase, fallbackCode, error instanceof Error ? error.message : String(error), {
    file: filePath,
    line: 0,
    col: 0,
    endLine: 0,
    endCol: 0,
  });
}
