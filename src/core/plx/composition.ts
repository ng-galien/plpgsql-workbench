import type { Loc, PlxModule, Statement, Visibility } from "./ast.js";
import { pointLoc } from "./ast.js";
import {
  type CompiledBundle,
  type CompileError,
  type CompileResult,
  type CompileWarning,
  compileModuleBundle,
  createDiagnostic,
  validateCompiledBundle,
} from "./compiler.js";
import { LexError, tokenize } from "./lexer.js";
import { ParseError } from "./parse-context.js";
import { parse } from "./parser.js";
import { walkStatements } from "./walker.js";

export interface CompositionInput {
  file: string;
  source: string;
}

export interface CompositionModuleInput {
  file: string;
  module: PlxModule;
}

export interface CompositionModuleResult {
  entityCount: number;
  errors: CompileError[];
  file: string;
  functionCount: number;
  moduleName: string | null;
  testCount: number;
  warnings: CompileWarning[];
}

export interface CompositionResult {
  errors: CompileError[];
  modules: CompositionModuleResult[];
  warnings: CompileWarning[];
}

interface CompiledModuleRecord {
  artifact: ReturnType<typeof compileModuleBundle>["artifact"];
  depends: Set<string>;
  file: string;
  moduleName: string;
  symbols: Map<string, Visibility>;
}

interface CompiledEntry {
  artifact: CompiledBundle["artifact"];
  file: string;
  result: CompileResult;
}

export async function compose(
  inputs: CompositionInput[],
  options: { validate?: boolean } = {},
): Promise<CompositionResult> {
  const warnings: CompileWarning[] = [];
  const errors: CompileError[] = [];
  const moduleResults: CompositionModuleResult[] = [];
  const compiled: CompiledEntry[] = [];

  for (const input of inputs) {
    let mod: PlxModule;
    try {
      mod = parse(tokenize(input.source, { file: input.file }), { kind: "module" });
    } catch (error: unknown) {
      const diagnostic = toCompositionError(error, input.file);
      errors.push(diagnostic);
      moduleResults.push({
        entityCount: 0,
        errors: [diagnostic],
        file: input.file,
        functionCount: 0,
        moduleName: null,
        testCount: 0,
        warnings: [],
      });
      continue;
    }
    const bundle = compileModuleBundle(mod);
    const result = options.validate === false ? bundle.result : await validateCompiledBundle(bundle);
    warnings.push(...result.warnings);
    errors.push(...result.errors);
    compiled.push({ artifact: bundle.artifact, file: input.file, result });
    moduleResults.push(toModuleResult(input.file, result, bundle.artifact));
  }

  if (errors.length > 0) {
    return { errors, modules: moduleResults, warnings };
  }

  analyzeComposition(compiled, errors);
  return { errors, modules: moduleResults, warnings };
}

export async function composeModules(
  inputs: CompositionModuleInput[],
  options: { validate?: boolean } = {},
): Promise<CompositionResult> {
  const warnings: CompileWarning[] = [];
  const errors: CompileError[] = [];
  const compiled: CompiledEntry[] = [];

  for (const input of inputs) {
    const bundle = compileModuleBundle(input.module);
    const result = options.validate === false ? bundle.result : await validateCompiledBundle(bundle);
    warnings.push(...result.warnings);
    errors.push(...result.errors);
    compiled.push({ artifact: bundle.artifact, file: input.file, result });
  }

  const moduleResults = compiled.map((entry) => toModuleResult(entry.file, entry.result, entry.artifact));

  if (errors.length > 0) {
    return { errors, modules: moduleResults, warnings };
  }

  analyzeComposition(compiled, errors);
  return { errors, modules: moduleResults, warnings };
}

// ---------- Shared composition analysis ----------

function toModuleResult(
  file: string,
  result: CompileResult,
  artifact: CompiledEntry["artifact"],
): CompositionModuleResult {
  return {
    entityCount: result.entityCount ?? 0,
    errors: result.errors,
    file,
    functionCount: result.functionCount,
    moduleName: artifact.module.name ?? null,
    testCount: result.testCount ?? 0,
    warnings: result.warnings,
  };
}

function analyzeComposition(compiled: CompiledEntry[], errors: CompileError[]): void {
  const registry = new Map<string, CompiledModuleRecord>();
  for (const entry of compiled) {
    const moduleName = entry.artifact.module.name;
    if (!moduleName) {
      errors.push(
        createDiagnostic(
          "semantic",
          "module.missing-declaration",
          `composition requires a module declaration for '${entry.file}'`,
          entry.artifact.module.moduleLoc ?? pointLoc(),
          "Add `module <name>` at the top of the PLX file before composing it with others.",
        ),
      );
      continue;
    }
    if (registry.has(moduleName)) {
      errors.push(
        createDiagnostic(
          "semantic",
          "module.duplicate-module",
          `duplicate module '${moduleName}' in composition`,
          entry.artifact.module.moduleLoc ?? pointLoc(),
          "Keep exactly one PLX source per module in a composed build.",
        ),
      );
      continue;
    }

    const symbols = new Map<string, Visibility>();
    for (const fn of entry.artifact.functions) {
      if (fn.schema === moduleName) symbols.set(fn.name, fn.visibility);
    }

    registry.set(moduleName, {
      artifact: entry.artifact,
      depends: new Set(entry.artifact.module.depends.map((dep) => dep.name)),
      file: entry.file,
      moduleName,
      symbols,
    });
  }

  for (const record of registry.values()) {
    for (const dep of record.artifact.module.depends) {
      if (dep.name === record.moduleName) {
        errors.push(
          createDiagnostic(
            "semantic",
            "module.dependency-cycle",
            `module '${record.moduleName}' cannot depend on itself`,
            dep.loc,
            "Remove the self dependency from the module header.",
          ),
        );
        continue;
      }
      if (!registry.has(dep.name)) {
        errors.push(
          createDiagnostic(
            "semantic",
            "module.missing-dependency",
            `module '${record.moduleName}' depends on missing module '${dep.name}'`,
            dep.loc,
            "Add the dependency to the composition or remove it from the module header.",
          ),
        );
      }
    }
  }

  detectDependencyCycles(registry, errors);

  for (const record of registry.values()) {
    for (const fn of record.artifact.functions) {
      for (const call of collectCalls(fn.body)) {
        const targetName = resolveCallTarget(call.name, record.artifact.aliases);
        if (!targetName.includes(".")) continue;

        const [targetModule, targetFunction] = splitQualifiedCall(targetName);
        if (!targetModule || !targetFunction || targetModule === record.moduleName) continue;

        if (!record.depends.has(targetModule)) {
          errors.push(
            createDiagnostic(
              "semantic",
              "module.missing-dependency",
              `module '${record.moduleName}' calls '${targetName}' without depending on '${targetModule}'`,
              call.loc,
              `Add '${targetModule}' to depends or stop calling '${targetName}'.`,
            ),
          );
          continue;
        }

        const targetRecord = registry.get(targetModule);
        if (!targetRecord) continue;

        const visibility = targetRecord.symbols.get(targetFunction);
        if (!visibility) {
          errors.push(
            createDiagnostic(
              "semantic",
              "module.unknown-export",
              `module '${record.moduleName}' calls unknown export '${targetName}'`,
              call.loc,
              `Export '${targetFunction}' from module '${targetModule}' or fix the call target.`,
            ),
          );
          continue;
        }

        if (visibility === "internal") {
          errors.push(
            createDiagnostic(
              "semantic",
              "module.private-symbol-access",
              `module '${record.moduleName}' cannot access internal symbol '${targetName}'`,
              call.loc,
              `Mark '${targetName}' as export or keep the call inside module '${targetModule}'.`,
            ),
          );
        }
      }
    }
  }
}

// ---------- Utilities ----------

export function collectCalls(stmts: Statement[]): Array<{ loc: Loc; name: string }> {
  const calls: Array<{ loc: Loc; name: string }> = [];
  walkStatements(stmts, {
    onExpression(expr) {
      if (expr.kind === "call") calls.push({ loc: expr.loc, name: expr.name });
    },
  });
  return calls;
}

function toCompositionError(error: unknown, file: string): CompileError {
  if (error instanceof LexError) {
    const span = {
      file,
      line: error.line,
      col: error.col,
      endLine: error.endLine,
      endCol: error.endCol,
    };
    return createDiagnostic("lex", error.code, error.message, span, error.hint);
  }
  if (error instanceof ParseError) {
    const span = {
      ...error.loc,
      file: error.loc.file ?? file,
    };
    return createDiagnostic("parse", error.code, error.message, span, error.hint);
  }
  return createDiagnostic("parse", "parse.invalid-syntax", error instanceof Error ? error.message : String(error), {
    file,
    ...pointLoc(),
  });
}

export function resolveCallTarget(name: string, aliases: Map<string, string>): string {
  const root = name.split(".")[0] ?? name;
  return aliases.get(root) ?? name;
}

function splitQualifiedCall(name: string): [string | undefined, string | undefined] {
  const [moduleName, fnName] = name.split(".", 2);
  return [moduleName, fnName];
}

function detectDependencyCycles(registry: Map<string, CompiledModuleRecord>, errors: CompileError[]): void {
  const visited = new Set<string>();
  const active = new Set<string>();
  const stack: string[] = [];
  const seen = new Set<string>();

  const dfs = (moduleName: string): void => {
    visited.add(moduleName);
    active.add(moduleName);
    stack.push(moduleName);

    const record = registry.get(moduleName);
    if (!record) return;

    for (const dep of record.artifact.module.depends) {
      if (!registry.has(dep.name)) continue;
      if (!visited.has(dep.name)) {
        dfs(dep.name);
        continue;
      }
      if (!active.has(dep.name)) continue;

      const cycleStart = stack.indexOf(dep.name);
      const cycle = cycleStart >= 0 ? [...stack.slice(cycleStart), dep.name] : [moduleName, dep.name];
      const key = cycle.join(" -> ");
      if (seen.has(key)) continue;
      seen.add(key);
      errors.push(
        createDiagnostic(
          "semantic",
          "module.dependency-cycle",
          `dependency cycle detected: ${cycle.join(" -> ")}`,
          dep.loc,
          "Break the cycle by removing at least one dependency edge.",
        ),
      );
    }

    active.delete(moduleName);
    stack.pop();
  };

  for (const moduleName of registry.keys()) {
    if (!visited.has(moduleName)) dfs(moduleName);
  }
}
