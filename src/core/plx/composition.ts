import type { Expression, Loc, Statement, Visibility } from "./ast.js";
import { pointLoc } from "./ast.js";
import {
  type CompiledModuleArtifact,
  type CompileError,
  type CompileResult,
  type CompileWarning,
  compile,
  compileAndValidate,
  createDiagnostic,
} from "./compiler.js";

export interface CompositionInput {
  file: string;
  source: string;
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
  artifact: CompiledModuleArtifact;
  depends: Set<string>;
  file: string;
  moduleName: string;
  symbols: Map<string, Visibility>;
}

export async function compose(
  inputs: CompositionInput[],
  options: { validate?: boolean } = {},
): Promise<CompositionResult> {
  const warnings: CompileWarning[] = [];
  const errors: CompileError[] = [];
  const compiled: Array<{
    artifact?: CompiledModuleArtifact;
    file: string;
    result: CompileResult;
  }> = [];

  for (const input of inputs) {
    const result = options.validate === false ? compile(input.source) : await compileAndValidate(input.source);
    warnings.push(...result.warnings);
    errors.push(...result.errors);
    compiled.push({
      artifact: result._artifact,
      file: input.file,
      result,
    });
  }

  const moduleResults = compiled.map((entry) => ({
    entityCount: entry.result.entityCount ?? 0,
    errors: entry.result.errors,
    file: entry.file,
    functionCount: entry.result.functionCount,
    moduleName: entry.artifact?.module.name ?? null,
    testCount: entry.result.testCount ?? 0,
    warnings: entry.result.warnings,
  }));

  if (errors.length > 0) {
    return { errors, modules: moduleResults, warnings };
  }

  const registry = new Map<string, CompiledModuleRecord>();
  for (const entry of compiled) {
    if (!entry.artifact) continue;
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

  return { errors, modules: moduleResults, warnings };
}

function collectCalls(stmts: Statement[]): Array<{ loc: Loc; name: string }> {
  const calls: Array<{ loc: Loc; name: string }> = [];
  for (const stmt of stmts) visitStatement(stmt, calls);
  return calls;
}

function visitStatement(stmt: Statement, calls: Array<{ loc: Loc; name: string }>): void {
  switch (stmt.kind) {
    case "assign":
    case "append":
      visitExpression(stmt.value, calls);
      return;
    case "assert":
      visitExpression(stmt.expression, calls);
      return;
    case "if":
      visitExpression(stmt.condition, calls);
      for (const inner of stmt.body) visitStatement(inner, calls);
      stmt.elsifs.forEach((branch) => {
        visitExpression(branch.condition, calls);
        for (const inner of branch.body) visitStatement(inner, calls);
      });
      if (stmt.elseBody) {
        for (const inner of stmt.elseBody) visitStatement(inner, calls);
      }
      return;
    case "for_in":
      for (const inner of stmt.body) visitStatement(inner, calls);
      return;
    case "match":
      visitExpression(stmt.subject, calls);
      stmt.arms.forEach((arm) => {
        visitExpression(arm.pattern, calls);
        for (const inner of arm.body) visitStatement(inner, calls);
      });
      if (stmt.elseBody) {
        for (const inner of stmt.elseBody) visitStatement(inner, calls);
      }
      return;
    case "return":
      visitExpression(stmt.value, calls);
      return;
    case "raise":
    case "sql_statement":
      return;
  }
}

function visitExpression(expr: Expression, calls: Array<{ loc: Loc; name: string }>): void {
  switch (expr.kind) {
    case "call":
      calls.push({ loc: expr.loc, name: expr.name });
      for (const arg of expr.args) visitExpression(arg, calls);
      return;
    case "array_literal":
      for (const element of expr.elements) visitExpression(element, calls);
      return;
    case "binary":
      visitExpression(expr.left, calls);
      visitExpression(expr.right, calls);
      return;
    case "case_expr":
      visitExpression(expr.subject, calls);
      expr.arms.forEach((arm) => {
        visitExpression(arm.pattern, calls);
        visitExpression(arm.result, calls);
      });
      if (expr.elseResult) visitExpression(expr.elseResult, calls);
      return;
    case "group":
      visitExpression(expr.expression, calls);
      return;
    case "json_literal":
      for (const entry of expr.entries) visitExpression(entry.value, calls);
      return;
    case "string_interp":
      expr.parts.forEach((part) => {
        if (typeof part !== "string") visitExpression(part, calls);
      });
      return;
    case "unary":
      visitExpression(expr.expression, calls);
      return;
    case "field_access":
    case "identifier":
    case "literal":
    case "sql_block":
      return;
  }
}

function resolveCallTarget(name: string, aliases: Map<string, string>): string {
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
