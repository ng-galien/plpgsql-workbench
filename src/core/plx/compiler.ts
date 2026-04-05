import type { Loc, PlxFunction, PlxModule } from "./ast.js";
import { pointLoc, stripLocPrefix } from "./ast.js";
import { type GeneratedLineMap, type GeneratedSourceMap, generateWithSourceMap } from "./codegen.js";
import type { ModuleContract } from "./contract.js";
import type { DdlArtifact } from "./entity-ddl.js";
import { expandEntities } from "./entity-expander.js";
import { expandEvents } from "./event-expander.js";
import { expandI18n } from "./i18n-expander.js";
import { LexError, tokenize } from "./lexer.js";
import { ParseError } from "./parse-context.js";
import { parse } from "./parser.js";
import { validateViewPayload } from "./sdui-schema.js";
import { buildEntityViewPayload } from "./sdui-view.js";
import { analyzeModule } from "./semantic.js";
import { expandTests } from "./test-expander.js";

export interface CompileResult {
  sql: string;
  ddlSql?: string;
  testSql?: string;
  errors: CompileError[];
  warnings: CompileWarning[];
  functionCount: number;
  entityCount?: number;
  testCount?: number;
}

export interface CompiledBundle {
  result: CompileResult;
  artifact: CompiledModuleArtifact;
  blocks: ValidationBlock[];
}

export interface CompileError {
  code: string;
  file?: string;
  line: number;
  col: number;
  endLine: number;
  endCol: number;
  span: Loc;
  message: string;
  hint?: string;
  phase: "lex" | "parse" | "semantic" | "codegen" | "validate";
}

export interface CompileWarning {
  code: string;
  file?: string;
  message: string;
  functionName: string;
  line: number;
  col: number;
  endLine: number;
  endCol: number;
  span: Loc;
  hint?: string;
  phase: "lex" | "parse" | "semantic" | "codegen" | "validate";
}

const LOC_RE = /plx:(\d+):(\d+)/;

interface ValidationBlock {
  sql: string;
  functionName: string;
  loc: Loc;
  sourceMap: GeneratedSourceMap;
}

interface CompiledModuleArtifact {
  aliases: Map<string, string>;
  ddlArtifacts: DdlArtifact[];
  functions: PlxFunction[];
  module: PlxModule;
  testFunctions: PlxFunction[];
}

interface CompileModuleOptions {
  dependencyContracts?: Map<string, ModuleContract>;
}

export function compile(source: string): CompileResult {
  const errors: CompileError[] = [];
  const warnings: CompileWarning[] = [];

  let tokens: ReturnType<typeof tokenize>;
  try {
    tokens = tokenize(source);
  } catch (e: unknown) {
    errors.push(toCompileError("lex", e, "lex.invalid-token"));
    return { sql: "", errors, warnings, functionCount: 0 };
  }

  let mod: ReturnType<typeof parse>;
  try {
    mod = parse(tokens);
  } catch (e: unknown) {
    errors.push(toCompileError("parse", e, "parse.invalid-syntax"));
    return { sql: "", errors, warnings, functionCount: 0 };
  }

  return compileModule(mod);
}

export function compileModule(mod: PlxModule): CompileResult {
  return compileModuleBundle(mod).result;
}

export function compileModuleBundle(mod: PlxModule, options: CompileModuleOptions = {}): CompiledBundle {
  const errors: CompileError[] = [];
  const warnings: CompileWarning[] = [];

  const semantic = analyzeModule(mod);
  for (const err of semantic.errors) {
    errors.push(createDiagnostic("semantic", err.code, `${err.owner}: ${err.message}`, err.loc, err.hint));
  }
  for (const warning of semantic.warnings) {
    warnings.push({
      ...createDiagnostic("semantic", warning.code, warning.message, warning.loc, warning.hint),
      functionName: warning.owner,
    });
  }
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  // Expand entities into functions + DDL
  const expandResult = expandEntities(mod);
  for (const err of expandResult.errors) {
    errors.push(createDiagnostic("codegen", "codegen.entity-expansion-failed", err.message, err.loc));
  }
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  for (const entity of mod.entities) {
    if (!entity.expose) continue;
    for (const error of validateViewPayload(buildEntityViewPayload(entity), entity.loc)) {
      errors.push(createDiagnostic("validate", error.code, error.message, error.loc));
    }
  }
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  const eventResult = expandEvents(mod, { dependencyContracts: options.dependencyContracts });
  for (const err of eventResult.errors) {
    errors.push(createDiagnostic("codegen", "codegen.event-expansion-failed", err.message, err.loc));
  }
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  const i18nResult = expandI18n(mod);
  errors.push(...i18nResult.errors);
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  // Expand tests into pgTAP functions
  const testResult = expandTests(mod.tests);
  for (const err of testResult.errors) {
    errors.push(createDiagnostic("codegen", "codegen.test-expansion-failed", err.message, err.loc));
  }

  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  const manualOverrides = new Set(
    mod.functions.filter((fn) => fn.attributes.includes("override")).map((fn) => `${fn.schema}.${fn.name}`),
  );
  const generatedFunctions = [...expandResult.functions, ...eventResult.functions];
  const generatedByName = new Set(generatedFunctions.map((fn) => `${fn.schema}.${fn.name}`));

  for (const fn of mod.functions) {
    const key = `${fn.schema}.${fn.name}`;
    if (!generatedByName.has(key)) continue;
    if (fn.attributes.includes("override")) continue;
    errors.push(
      createDiagnostic(
        "codegen",
        "codegen.generated-function-collision",
        `manual function '${key}' collides with a generated PLX function; mark it with [override] to replace the generated version`,
        fn.loc,
      ),
    );
  }
  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  // Merge expanded functions with hand-written ones
  const allFunctions = [
    ...mod.functions,
    ...generatedFunctions.filter((fn) => !manualOverrides.has(`${fn.schema}.${fn.name}`)),
  ];
  const schemaArtifacts = buildSchemaArtifacts(
    allFunctions,
    testResult.functions,
    [expandResult.ddlArtifacts, eventResult.ddlArtifacts],
    mod.i18n.length > 0 && mod.name ? [mod.name] : [],
  );

  // Build alias map from imports
  const aliases = new Map<string, string>();
  for (const imp of mod.imports) {
    aliases.set(imp.alias, imp.original);
  }
  const returnTypes = new Map<string, string>();
  for (const fn of [...allFunctions, ...testResult.functions]) {
    returnTypes.set(`${fn.schema}.${fn.name}`, fn.returnType);
  }

  const sqlParts: string[] = [];
  const validationBlocks: ValidationBlock[] = [];
  for (const fn of allFunctions) {
    try {
      const generated = generateWithSourceMap(fn, aliases, returnTypes);
      sqlParts.push(generated.sql);
      validationBlocks.push({
        sql: generated.sql,
        functionName: `${fn.schema}.${fn.name}`,
        loc: fn.loc,
        sourceMap: generated.sourceMap,
      });
    } catch (e: unknown) {
      errors.push(toCompileError("codegen", e, "codegen.generate-failed", fn.loc));
    }
  }

  // Generate test function SQL separately
  const testSqlParts: string[] = [];
  for (const fn of testResult.functions) {
    try {
      const generated = generateWithSourceMap(fn, aliases, returnTypes);
      testSqlParts.push(generated.sql);
      validationBlocks.push({
        sql: generated.sql,
        functionName: `${fn.schema}.${fn.name}`,
        loc: fn.loc,
        sourceMap: generated.sourceMap,
      });
    } catch (e: unknown) {
      errors.push(toCompileError("codegen", e, "codegen.generate-failed", fn.loc));
    }
  }

  if (errors.length > 0) {
    return emptyBundle({ sql: "", errors, warnings, functionCount: 0 }, mod);
  }

  const ddlArtifacts = [
    ...schemaArtifacts,
    ...expandResult.ddlArtifacts,
    ...eventResult.ddlArtifacts,
    ...i18nResult.artifacts,
  ];
  const ddlFragments = ddlArtifacts.map((artifact) => artifact.sql);
  const ddlSql = ddlFragments.length > 0 ? ddlFragments.join("\n\n") : undefined;
  const testSql = testSqlParts.length > 0 ? testSqlParts.join("\n\n") : undefined;

  return {
    result: {
      sql: sqlParts.join("\n\n"),
      ddlSql,
      testSql,
      errors: [],
      warnings,
      functionCount: allFunctions.length,
      entityCount: mod.entities.length,
      testCount: testResult.functions.length,
    },
    blocks: validationBlocks,
    artifact: {
      aliases,
      ddlArtifacts,
      functions: allFunctions,
      module: mod,
      testFunctions: testResult.functions,
    },
  };
}

function buildSchemaArtifacts(
  functions: readonly PlxFunction[],
  testFunctions: readonly PlxFunction[],
  ddlSources: ReadonlyArray<readonly DdlArtifact[]>,
  extraSchemas: readonly string[] = [],
): DdlArtifact[] {
  const schemas = new Set<string>();

  for (const fn of functions) {
    if (fn.schema) schemas.add(fn.schema);
  }
  for (const fn of testFunctions) {
    if (fn.schema) schemas.add(fn.schema);
  }
  for (const artifacts of ddlSources) {
    for (const artifact of artifacts) {
      const match = artifact.key.match(/^ddl:schema:(.+)$/);
      if (match?.[1]) schemas.add(match[1]);
    }
  }
  for (const schema of extraSchemas) schemas.add(schema);

  return [...schemas].sort().map((schema) => ({
    key: `ddl:schema:${schema}`,
    name: `${schema}.schema`,
    sql: `CREATE SCHEMA IF NOT EXISTS "${schema.replace(/"/g, '""')}";`,
    dependsOn: [],
  }));
}

function emptyBundle(result: CompileResult, mod: PlxModule): CompiledBundle {
  return {
    result,
    blocks: [],
    artifact: {
      aliases: new Map(),
      ddlArtifacts: [],
      functions: [],
      module: mod,
      testFunctions: [],
    },
  };
}

/**
 * Compile with PG parser validation. Uses dynamic import to avoid loading
 * the heavy WASM module (~4GB) when validation is not requested.
 */
export async function compileAndValidate(source: string): Promise<CompileResult> {
  const errors: CompileError[] = [];
  const warnings: CompileWarning[] = [];

  let tokens: ReturnType<typeof tokenize>;
  try {
    tokens = tokenize(source);
  } catch (e: unknown) {
    errors.push(toCompileError("lex", e, "lex.invalid-token"));
    return { sql: "", errors, warnings, functionCount: 0 };
  }

  let mod: ReturnType<typeof parse>;
  try {
    mod = parse(tokens);
  } catch (e: unknown) {
    errors.push(toCompileError("parse", e, "parse.invalid-syntax"));
    return { sql: "", errors, warnings, functionCount: 0 };
  }

  const bundle = compileModuleBundle(mod);
  return await validateCompiledBundle(bundle);
}

export async function compileModuleAndValidate(
  mod: PlxModule,
  options: CompileModuleOptions = {},
): Promise<CompileResult> {
  const bundle = compileModuleBundle(mod, options);
  return await validateCompiledBundle(bundle);
}

export async function validateCompiledBundle(bundle: CompiledBundle): Promise<CompileResult> {
  const { result } = bundle;
  if (result.errors.length > 0) return result;

  const warnings: CompileWarning[] = [...result.warnings];
  const blocks =
    bundle.blocks.length > 0
      ? bundle.blocks
      : result.sql
        ? [
            {
              sql: result.sql,
              functionName: "unknown",
              loc: pointLoc(),
              sourceMap: { lines: [] },
            },
          ]
        : [];

  let parsePlPgSQLSync: ((query: string) => unknown) | undefined;
  try {
    // Dynamic import — only loads WASM when validation is actually called
    const parser = await import("@libpg-query/parser");
    await parser.loadModule();
    parsePlPgSQLSync = parser.parsePlPgSQLSync;
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      ...result,
      warnings: [
        ...warnings,
        {
          ...createDiagnostic(
            "validate",
            "validate.validator-unavailable",
            `PG validator unavailable: ${msg}`,
            pointLoc(),
          ),
          functionName: "validator",
        },
      ],
    };
  }

  for (const block of blocks) {
    try {
      parsePlPgSQLSync(block.sql);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      warnings.push({
        ...createDiagnostic(
          "validate",
          "validate.pg-parse-error",
          `PG parse: ${msg}`,
          resolveValidationLoc(msg, block),
          "Inspect the generated SQL around this span or rerun with --json for the mapped location.",
        ),
        functionName: block.functionName,
      });
    }
  }

  return { ...result, warnings };
}

function extractLoc(msg: string): Loc {
  const m = msg.match(LOC_RE);
  return m ? pointLoc(Number(m[1]), Number(m[2])) : pointLoc();
}

function resolveValidationLoc(message: string, block: ValidationBlock): Loc {
  const generatedLine = extractGeneratedLine(message);
  if (generatedLine !== undefined) {
    const lineMap = block.sourceMap.lines.find((line) => line.generatedLine === generatedLine);
    if (lineMap) {
      const token = extractNearToken(message);
      return resolveLineLoc(lineMap, token) ?? lineMap.loc ?? block.loc;
    }
  }

  const token = extractNearToken(message);
  if (token) {
    const segment = findBestSegment(block.sourceMap, token);
    if (segment) return segment.loc;
  }

  if (/end of input/i.test(message)) {
    const lastMapped =
      [...block.sourceMap.lines].reverse().find((line) => line.segments.length > 0) ??
      [...block.sourceMap.lines]
        .reverse()
        .find((line) => line.loc && (line.loc.line !== block.loc.line || line.loc.col !== block.loc.col));
    if (lastMapped) {
      return lastMapped.segments.at(-1)?.loc ?? lastMapped.loc ?? block.loc;
    }
  }

  return block.loc;
}

function extractGeneratedLine(message: string): number | undefined {
  const match = message.match(/\bline\s+(\d+)\b/i);
  return match ? Number(match[1]) : undefined;
}

function extractNearToken(message: string): string | undefined {
  const match = message.match(/at or near "([^"]+)"/i);
  return match?.[1];
}

function resolveLineLoc(line: GeneratedLineMap, token: string | undefined): Loc | undefined {
  if (!token) return line.segments.at(-1)?.loc ?? line.loc;
  const segment = findBestSegmentInLine(line, token);
  if (segment) return segment.loc;
  return line.loc;
}

function findBestSegment(
  sourceMap: GeneratedSourceMap,
  token: string,
): GeneratedLineMap["segments"][number] | undefined {
  const scored = sourceMap.lines
    .flatMap((line) => line.segments.map((segment) => ({ segment, score: scoreSegment(segment.text, token) })))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.segment.text.length - b.segment.text.length);
  return scored[0]?.segment;
}

function findBestSegmentInLine(
  line: GeneratedLineMap,
  token: string,
): GeneratedLineMap["segments"][number] | undefined {
  const scored = line.segments
    .map((segment) => ({ segment, score: scoreSegment(segment.text, token) }))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.segment.text.length - b.segment.text.length);
  return scored[0]?.segment;
}

function scoreSegment(text: string, token: string): number {
  if (!token) return 0;
  if (text === token) return 4;
  if (text.startsWith(token)) return 3;
  if (text.includes(token)) return 2;
  if (token.length > 1 && text.replace(/\s+/g, "").includes(token.replace(/\s+/g, ""))) return 1;
  return 0;
}

export function createDiagnostic(
  phase: CompileError["phase"],
  code: string,
  message: string,
  span: Loc,
  hint?: string,
): CompileError {
  return {
    phase,
    code,
    file: span.file,
    message: stripLocPrefix(message),
    hint,
    line: span.line,
    col: span.col,
    endLine: span.endLine,
    endCol: span.endCol,
    span,
  };
}

function toCompileError(
  phase: CompileError["phase"],
  error: unknown,
  fallbackCode: string,
  fallbackLoc?: Loc,
): CompileError {
  const message = error instanceof Error ? error.message : String(error);
  if (error instanceof LexError) {
    return createDiagnostic(phase, error.code, message, toLoc(error), error.hint);
  }
  if (error instanceof ParseError) {
    return createDiagnostic(phase, error.code, message, error.loc, error.hint);
  }
  return createDiagnostic(phase, fallbackCode, message, fallbackLoc ?? extractLoc(message));
}

function toLoc(loc: Pick<Loc, "file" | "line" | "col" | "endLine" | "endCol">): Loc {
  return {
    file: loc.file,
    line: loc.line,
    col: loc.col,
    endLine: loc.endLine,
    endCol: loc.endCol,
  };
}
