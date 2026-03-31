import type { Expression, Loc, Param, PlxEntity, PlxModule, PlxTest, PlxTrait, Statement } from "./ast.js";

export interface SemanticIssue {
  loc: Loc;
  message: string;
  owner: string;
}

export interface SemanticWarning {
  loc: Loc;
  message: string;
  owner: string;
}

export interface SemanticResult {
  errors: SemanticIssue[];
  warnings: SemanticWarning[];
}

const RESERVED_IDENTIFIERS = new Set(["null"]);

export function analyzeModule(mod: PlxModule): SemanticResult {
  const errors: SemanticIssue[] = [];
  const warnings: SemanticWarning[] = [];
  const importAliases = new Map<string, Loc>();
  const usedImports = new Set<string>();

  for (const imp of mod.imports) {
    const existing = importAliases.get(imp.alias);
    if (existing) {
      errors.push({
        loc: imp.loc,
        owner: "module",
        message: `duplicate import alias '${imp.alias}'`,
      });
      continue;
    }
    importAliases.set(imp.alias, imp.loc);
  }

  for (const fn of mod.functions) {
    analyzeCallable(`${fn.schema}.${fn.name}`, fn.params, fn.body, importAliases, usedImports, errors);
  }

  for (const test of mod.tests) {
    analyzeCallable(`test "${test.name}"`, [], test.body, importAliases, usedImports, errors);
  }

  for (const trait of mod.traits) {
    analyzeTrait(trait, importAliases, usedImports, errors);
  }

  for (const entity of mod.entities) {
    analyzeEntity(entity, importAliases, usedImports, errors);
  }

  for (const imp of mod.imports) {
    if (!usedImports.has(imp.alias)) {
      warnings.push({
        loc: imp.loc,
        owner: "module",
        message: `unused import alias '${imp.alias}'`,
      });
    }
  }

  return { errors, warnings };
}

function analyzeTrait(
  trait: PlxTrait,
  importAliases: Map<string, Loc>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
): void {
  const seen = new Set<string>();
  for (const field of trait.fields) {
    if (seen.has(field.name)) {
      errors.push({
        loc: field.loc,
        owner: `trait ${trait.name}`,
        message: `duplicate field '${field.name}'`,
      });
      continue;
    }
    seen.add(field.name);
  }

  for (const hook of trait.hooks) {
    analyzeBody(`trait ${trait.name} ${hook.event}`, [], hook.body, importAliases, usedImports, errors);
  }
}

function analyzeEntity(
  entity: PlxEntity,
  importAliases: Map<string, Loc>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
): void {
  const entityName = `${entity.schema}.${entity.name}`;
  checkDuplicates(
    entity.fields.map((field) => ({ name: field.name, loc: field.loc })),
    `entity ${entityName}`,
    "field",
    errors,
  );
  checkDuplicates(
    entity.actions.map((action) => ({ name: action.name, loc: entity.loc })),
    `entity ${entityName}`,
    "action",
    errors,
  );
  checkDuplicates(
    entity.strategies.map((strategy) => ({ name: strategy.slot, loc: strategy.loc })),
    `entity ${entityName}`,
    "strategy slot",
    errors,
  );

  if (entity.states) {
    const stateSet = new Set(entity.states.values);
    for (const state of entity.updateStates ?? []) {
      if (!stateSet.has(state)) {
        errors.push({
          loc: entity.loc,
          owner: `entity ${entityName}`,
          message: `update_states references unknown state '${state}'`,
        });
      }
    }

    for (const tr of entity.states.transitions) {
      if (!stateSet.has(tr.from)) {
        errors.push({
          loc: tr.loc,
          owner: `entity ${entityName}`,
          message: `transition '${tr.name}' references unknown from-state '${tr.from}'`,
        });
      }
      if (!stateSet.has(tr.to)) {
        errors.push({
          loc: tr.loc,
          owner: `entity ${entityName}`,
          message: `transition '${tr.name}' references unknown to-state '${tr.to}'`,
        });
      }
      if (tr.body) {
        const implicit = new Set<string>(["p_id"]);
        if (tr.guard) implicit.add("row");
        analyzeBody(
          `entity ${entityName} transition ${tr.name}`,
          [],
          tr.body,
          importAliases,
          usedImports,
          errors,
          implicit,
        );
      }
    }
  }

  for (const hook of entity.hooks) {
    analyzeBody(
      `entity ${entityName} ${hook.event}`,
      hook.params.map((name) => ({ name, type: "unknown", nullable: true }) as Param),
      hook.body,
      importAliases,
      usedImports,
      errors,
    );
  }
}

function analyzeCallable(
  owner: string,
  params: Param[],
  body: Statement[],
  importAliases: Map<string, Loc>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
): void {
  const seenParams = new Set<string>();
  for (const param of params) {
    if (seenParams.has(param.name)) {
      errors.push({
        loc: inferredLoc(body) ?? { line: 0, col: 0 },
        owner,
        message: `duplicate parameter '${param.name}'`,
      });
      continue;
    }
    seenParams.add(param.name);
  }

  analyzeBody(owner, params, body, importAliases, usedImports, errors);
}

function analyzeBody(
  owner: string,
  params: Param[],
  body: Statement[],
  importAliases: Map<string, Loc>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
  implicitNames = new Set<string>(),
): void {
  const locals = collectLocals(body);
  const known = new Set<string>([...params.map((p) => p.name), ...locals, ...implicitNames]);
  const paramsSet = new Set(params.map((p) => p.name));

  visitStatements(body, (stmt) => {
    if ((stmt.kind === "assign" || stmt.kind === "append") && stmt.target !== "_" && paramsSet.has(stmt.target)) {
      errors.push({
        loc: stmt.loc,
        owner,
        message: `cannot assign to parameter '${stmt.target}'`,
      });
    }
  });

  visitStatements(body, (stmt) => {
    switch (stmt.kind) {
      case "assign":
        if (stmt.target !== "_") {
          checkShadowing(stmt.target, stmt.loc, owner, importAliases, errors);
        }
        analyzeExpression(stmt.value, owner, known, importAliases, usedImports, errors);
        break;
      case "append":
        checkShadowing(stmt.target, stmt.loc, owner, importAliases, errors);
        analyzeExpression(stmt.value, owner, known, importAliases, usedImports, errors);
        break;
      case "if":
        analyzeExpression(stmt.condition, owner, known, importAliases, usedImports, errors);
        break;
      case "return":
        analyzeExpression(stmt.value, owner, known, importAliases, usedImports, errors);
        break;
      case "match":
        analyzeExpression(stmt.subject, owner, known, importAliases, usedImports, errors);
        for (const arm of stmt.arms) analyzeExpression(arm.pattern, owner, known, importAliases, usedImports, errors);
        break;
      case "assert":
        analyzeExpression(stmt.expression, owner, known, importAliases, usedImports, errors);
        break;
      default:
        break;
    }
  });
}

function analyzeExpression(
  expr: Expression,
  owner: string,
  known: Set<string>,
  importAliases: Map<string, Loc>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
): void {
  switch (expr.kind) {
    case "identifier":
      if (!known.has(expr.name) && !RESERVED_IDENTIFIERS.has(expr.name)) {
        errors.push({
          loc: expr.loc,
          owner,
          message: `unknown identifier '${expr.name}'`,
        });
      }
      return;
    case "field_access": {
      const root = expr.object.split(".")[0] ?? expr.object;
      if (!known.has(root) && !RESERVED_IDENTIFIERS.has(root)) {
        errors.push({
          loc: expr.loc,
          owner,
          message: `unknown identifier '${root}'`,
        });
      }
      return;
    }
    case "call": {
      const callRoot = expr.name.split(".")[0] ?? expr.name;
      if (importAliases.has(expr.name)) usedImports.add(expr.name);
      if (importAliases.has(callRoot)) usedImports.add(callRoot);
      for (const arg of expr.args) {
        analyzeExpression(arg, owner, known, importAliases, usedImports, errors);
      }
      return;
    }
    case "binary":
      analyzeExpression(expr.left, owner, known, importAliases, usedImports, errors);
      if (expr.op !== "::") {
        analyzeExpression(expr.right, owner, known, importAliases, usedImports, errors);
      }
      return;
    case "unary":
      analyzeExpression(expr.expression, owner, known, importAliases, usedImports, errors);
      return;
    case "group":
      analyzeExpression(expr.expression, owner, known, importAliases, usedImports, errors);
      return;
    case "case_expr":
      analyzeExpression(expr.subject, owner, known, importAliases, usedImports, errors);
      for (const arm of expr.arms) {
        analyzeExpression(arm.pattern, owner, known, importAliases, usedImports, errors);
        analyzeExpression(arm.result, owner, known, importAliases, usedImports, errors);
      }
      if (expr.elseResult) analyzeExpression(expr.elseResult, owner, known, importAliases, usedImports, errors);
      return;
    case "array_literal":
      for (const element of expr.elements) {
        analyzeExpression(element, owner, known, importAliases, usedImports, errors);
      }
      return;
    case "json_literal":
      for (const entry of expr.entries) {
        analyzeExpression(entry.value, owner, known, importAliases, usedImports, errors);
      }
      return;
    case "string_interp":
      for (const part of expr.parts) {
        if (typeof part !== "string") analyzeExpression(part, owner, known, importAliases, usedImports, errors);
      }
      return;
    case "literal":
    case "sql_block":
      return;
  }
}

function collectLocals(stmts: Statement[]): Set<string> {
  const locals = new Set<string>();
  visitStatements(stmts, (stmt) => {
    if (stmt.kind === "assign" && stmt.target !== "_") locals.add(stmt.target);
    if (stmt.kind === "append") locals.add(stmt.target);
    if (stmt.kind === "for_in") locals.add(stmt.variable);
  });
  return locals;
}

function visitStatements(stmts: Statement[], visit: (stmt: Statement) => void): void {
  for (const stmt of stmts) {
    visit(stmt);
    switch (stmt.kind) {
      case "if":
        visitStatements(stmt.body, visit);
        for (const elsif of stmt.elsifs) visitStatements(elsif.body, visit);
        if (stmt.elseBody) visitStatements(stmt.elseBody, visit);
        break;
      case "for_in":
        visitStatements(stmt.body, visit);
        break;
      case "match":
        for (const arm of stmt.arms) visitStatements(arm.body, visit);
        if (stmt.elseBody) visitStatements(stmt.elseBody, visit);
        break;
      default:
        break;
    }
  }
}

function checkDuplicates(
  entries: { name: string; loc: Loc }[],
  owner: string,
  label: string,
  errors: SemanticIssue[],
): void {
  const seen = new Set<string>();
  for (const entry of entries) {
    if (seen.has(entry.name)) {
      errors.push({
        loc: entry.loc,
        owner,
        message: `duplicate ${label} '${entry.name}'`,
      });
      continue;
    }
    seen.add(entry.name);
  }
}

function checkShadowing(
  name: string,
  loc: Loc,
  owner: string,
  importAliases: Map<string, Loc>,
  errors: SemanticIssue[],
): void {
  if (!importAliases.has(name)) return;
  errors.push({
    loc,
    owner,
    message: `local name '${name}' shadows import alias '${name}'`,
  });
}

function inferredLoc(stmts: Statement[]): Loc | undefined {
  return stmts[0]?.loc;
}
