import type { Expression, Loc, PlxEntity, PlxFunction, PlxModule, PlxTest, PlxTrait, Statement } from "./ast.js";
import { pointLoc } from "./ast.js";
import { walkStatements } from "./walker.js";

export interface SemanticIssue {
  code: string;
  hint?: string;
  loc: Loc;
  message: string;
  owner: string;
}

export interface SemanticWarning {
  code: string;
  hint?: string;
  loc: Loc;
  message: string;
  owner: string;
}

export interface SemanticResult {
  errors: SemanticIssue[];
  warnings: SemanticWarning[];
}

type TypeKind = "boolean" | "int" | "jsonb" | "null" | "numeric" | "record" | "text" | "unknown" | "void";

interface TypeInfo {
  kind: TypeKind;
  raw: string;
}

interface AnalysisContext {
  bindings: Map<string, TypeInfo>;
  errors: SemanticIssue[];
  importAliases: Map<string, Loc>;
  importTargets: Map<string, string>;
  knownNames: Set<string>;
  owner: string;
  paramNames: Set<string>;
  returnType: TypeInfo;
  usedImports: Set<string>;
  warnings: SemanticWarning[];
}

const RESERVED_IDENTIFIERS = new Set(["null"]);
const NUMERIC_KINDS = new Set<TypeKind>(["int", "numeric"]);

export function analyzeModule(mod: PlxModule): SemanticResult {
  const errors: SemanticIssue[] = [];
  const warnings: SemanticWarning[] = [];
  const importAliases = new Map<string, Loc>();
  const importTargets = new Map<string, string>();
  const usedImports = new Set<string>();

  checkDuplicates(
    mod.traits.map((trait) => ({ loc: trait.loc, name: trait.name })),
    "module",
    "trait",
    "semantic.duplicate-trait",
    "Rename or remove the duplicated trait declaration.",
    errors,
  );
  checkDuplicates(
    mod.entities.map((entity) => ({ loc: entity.loc, name: `${entity.schema}.${entity.name}` })),
    "module",
    "entity",
    "semantic.duplicate-entity",
    "Rename or remove the duplicated entity declaration.",
    errors,
  );
  checkDuplicates(
    mod.functions.map((fn) => ({ loc: fn.loc, name: `${fn.schema}.${fn.name}` })),
    "module",
    "function",
    "semantic.duplicate-function",
    "Rename or remove the duplicated function declaration.",
    errors,
  );
  checkDuplicates(
    mod.tests.map((test) => ({ loc: test.loc, name: test.name })),
    "module",
    "test",
    "semantic.duplicate-test",
    "Rename or remove the duplicated test declaration.",
    errors,
  );

  for (const imp of mod.imports) {
    const existing = importAliases.get(imp.alias);
    if (existing) {
      errors.push({
        code: "semantic.duplicate-import-alias",
        hint: "Rename or remove one of the conflicting import aliases.",
        loc: imp.loc,
        owner: "module",
        message: `duplicate import alias '${imp.alias}'`,
      });
      continue;
    }
    importAliases.set(imp.alias, imp.loc);
    importTargets.set(imp.alias, imp.original);
  }

  for (const fn of mod.functions) {
    analyzeCallable(fn, importAliases, importTargets, usedImports, errors, warnings);
  }

  for (const test of mod.tests) {
    analyzeTest(test, importAliases, importTargets, usedImports, errors, warnings);
  }

  for (const trait of mod.traits) {
    analyzeTrait(trait, importAliases, importTargets, usedImports, errors, warnings);
  }

  for (const entity of mod.entities) {
    analyzeEntity(entity, importAliases, importTargets, usedImports, errors, warnings);
  }

  for (const imp of mod.imports) {
    if (!usedImports.has(imp.alias)) {
      warnings.push({
        code: "semantic.unused-import-alias",
        hint: "Remove the import or use the alias in PLX code.",
        loc: imp.loc,
        owner: "module",
        message: `unused import alias '${imp.alias}'`,
      });
    }
  }

  return { errors, warnings };
}

function analyzeCallable(
  fn: PlxFunction,
  importAliases: Map<string, Loc>,
  importTargets: Map<string, string>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
  warnings: SemanticWarning[],
): void {
  const owner = `${fn.schema}.${fn.name}`;
  const seenParams = new Set<string>();
  for (const param of fn.params) {
    if (seenParams.has(param.name)) {
      errors.push({
        code: "semantic.duplicate-parameter",
        hint: "Rename one of the parameters so each function argument is unique.",
        loc: param.loc,
        owner,
        message: `duplicate parameter '${param.name}'`,
      });
      continue;
    }
    seenParams.add(param.name);
  }

  const knownNames = new Set<string>([...fn.params.map((param) => param.name), ...collectLocals(fn.body)]);
  const bindings = new Map<string, TypeInfo>();
  for (const param of fn.params) {
    bindings.set(param.name, declaredType(param.type));
  }

  const ctx: AnalysisContext = {
    bindings,
    errors,
    importAliases,
    importTargets,
    knownNames,
    owner,
    paramNames: new Set(fn.params.map((param) => param.name)),
    returnType: declaredType(fn.returnType),
    usedImports,
    warnings,
  };

  analyzeStatements(fn.body, ctx);
}

function analyzeTest(
  test: PlxTest,
  importAliases: Map<string, Loc>,
  importTargets: Map<string, string>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
  warnings: SemanticWarning[],
): void {
  const ctx: AnalysisContext = {
    bindings: new Map(),
    errors,
    importAliases,
    importTargets,
    knownNames: collectLocals(test.body),
    owner: `test "${test.name}"`,
    paramNames: new Set(),
    returnType: { kind: "unknown", raw: "unknown" },
    usedImports,
    warnings,
  };

  analyzeStatements(test.body, ctx);
}

function analyzeTrait(
  trait: PlxTrait,
  importAliases: Map<string, Loc>,
  importTargets: Map<string, string>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
  warnings: SemanticWarning[],
): void {
  checkDuplicates(
    trait.fields.map((field) => ({ loc: field.loc, name: field.name })),
    `trait ${trait.name}`,
    "field",
    "semantic.duplicate-trait-field",
    "Rename or remove the duplicated trait field.",
    errors,
  );

  for (const hook of trait.hooks) {
    const ctx: AnalysisContext = {
      bindings: new Map(),
      errors,
      importAliases,
      importTargets,
      knownNames: collectLocals(hook.body),
      owner: `trait ${trait.name} ${hook.event}`,
      paramNames: new Set(),
      returnType: { kind: "unknown", raw: "unknown" },
      usedImports,
      warnings,
    };
    analyzeStatements(hook.body, ctx);
  }
}

function analyzeEntity(
  entity: PlxEntity,
  importAliases: Map<string, Loc>,
  importTargets: Map<string, string>,
  usedImports: Set<string>,
  errors: SemanticIssue[],
  warnings: SemanticWarning[],
): void {
  const entityName = `${entity.schema}.${entity.name}`;

  checkDuplicates(
    entity.fields.map((field) => ({ loc: field.loc, name: field.name })),
    `entity ${entityName}`,
    "field",
    "semantic.duplicate-entity-field",
    "Rename or remove the duplicated entity field.",
    errors,
  );

  if (entity.storage === "hybrid") {
    for (const field of entity.payload) {
      if (field.ref) {
        errors.push({
          code: "semantic.payload-ref-unsupported",
          hint: "Move relational references to columns:, not payload:.",
          loc: field.loc,
          owner: `entity ${entityName}`,
          message: `payload field '${field.name}' cannot declare ref(${field.ref})`,
        });
      }
      if (field.unique) {
        errors.push({
          code: "semantic.payload-unique-unsupported",
          hint: "Move unique fields to columns or keep the entity in row storage.",
          loc: field.loc,
          owner: `entity ${entityName}`,
          message: `payload field '${field.name}' cannot be unique in columns + payload storage`,
        });
      }
    }
  }
  checkDuplicates(
    entity.actions.map((action) => ({ loc: entity.loc, name: action.name })),
    `entity ${entityName}`,
    "action",
    "semantic.duplicate-entity-action",
    "Rename or remove the duplicated action.",
    errors,
  );
  checkDuplicates(
    entity.strategies.map((strategy) => ({ loc: strategy.loc, name: strategy.slot })),
    `entity ${entityName}`,
    "strategy slot",
    "semantic.duplicate-strategy-slot",
    "Keep only one strategy implementation per slot.",
    errors,
  );

  if (entity.states) {
    const stateSet = new Set(entity.states.values);
    for (const state of entity.updateStates ?? []) {
      if (!stateSet.has(state)) {
        errors.push({
          code: "semantic.unknown-update-state",
          hint: "Only reference states declared in the entity state machine.",
          loc: entity.loc,
          owner: `entity ${entityName}`,
          message: `update_states references unknown state '${state}'`,
        });
      }
    }

    for (const transition of entity.states.transitions) {
      if (!stateSet.has(transition.from)) {
        errors.push({
          code: "semantic.unknown-transition-from-state",
          hint: "Declare the source state in the entity state machine before using it in a transition.",
          loc: transition.loc,
          owner: `entity ${entityName}`,
          message: `transition '${transition.name}' references unknown from-state '${transition.from}'`,
        });
      }
      if (!stateSet.has(transition.to)) {
        errors.push({
          code: "semantic.unknown-transition-to-state",
          hint: "Declare the target state in the entity state machine before using it in a transition.",
          loc: transition.loc,
          owner: `entity ${entityName}`,
          message: `transition '${transition.name}' references unknown to-state '${transition.to}'`,
        });
      }
      if (transition.body) {
        const bindings = new Map<string, TypeInfo>([
          ["p_id", declaredType("int")],
          ["row", declaredType("record")],
        ]);
        const ctx: AnalysisContext = {
          bindings,
          errors,
          importAliases,
          importTargets,
          knownNames: new Set<string>(["p_id", "row", ...collectLocals(transition.body)]),
          owner: `entity ${entityName} transition ${transition.name}`,
          paramNames: new Set(["p_id"]),
          returnType: { kind: "unknown", raw: "unknown" },
          usedImports,
          warnings,
        };
        analyzeStatements(transition.body, ctx);
      }
    }
  }

  for (const hook of entity.hooks) {
    const bindings = new Map<string, TypeInfo>();
    if (hook.event === "validate_create") {
      bindings.set("p_data", declaredType("jsonb"));
      bindings.set("p_row", declaredType(entity.table));
    } else if (hook.event === "validate_update") {
      bindings.set("p_id", declaredType("text"));
      bindings.set("p_data", declaredType("jsonb"));
      bindings.set("p_patch", declaredType("jsonb"));
      bindings.set("current", declaredType(entity.table));
      bindings.set("p_row", declaredType(entity.table));
    } else if (hook.event === "validate_delete") {
      bindings.set("p_id", declaredType("text"));
      bindings.set("current", declaredType(entity.table));
    }
    for (const paramName of hook.params) bindings.set(paramName, { kind: "unknown", raw: "unknown" });
    const ctx: AnalysisContext = {
      bindings,
      errors,
      importAliases,
      importTargets,
      knownNames: new Set<string>([...bindings.keys(), ...hook.params, ...collectLocals(hook.body)]),
      owner: `entity ${entityName} ${hook.event}`,
      paramNames: new Set(hook.params),
      returnType: { kind: "unknown", raw: "unknown" },
      usedImports,
      warnings,
    };
    analyzeStatements(hook.body, ctx);
  }
}

function analyzeStatements(stmts: Statement[], ctx: AnalysisContext): void {
  for (const stmt of stmts) {
    analyzeStatement(stmt, ctx);
  }
}

function analyzeStatement(stmt: Statement, ctx: AnalysisContext): void {
  switch (stmt.kind) {
    case "assign": {
      if (stmt.target !== "_") {
        checkShadowing(stmt.target, stmt.loc, ctx);
        if (ctx.paramNames.has(stmt.target)) {
          ctx.errors.push({
            code: "semantic.assign-parameter",
            hint: "Assign to a local variable instead of mutating a function parameter.",
            loc: stmt.loc,
            owner: ctx.owner,
            message: `cannot assign to parameter '${stmt.target}'`,
          });
        }
      }

      const valueType = inferExpressionType(stmt.value, ctx);
      maybeAnalyzeSqlBlock(stmt.value, stmt.loc, ctx);

      if (stmt.target !== "_") {
        const current = ctx.bindings.get(stmt.target) ?? { kind: "unknown", raw: "unknown" };
        if (current.kind !== "unknown" && valueType.kind !== "unknown" && !typesCompatible(current, valueType)) {
          ctx.warnings.push({
            code: "type.assignment-mismatch",
            hint: `Assign a value compatible with '${current.raw}' or cast it explicitly.`,
            loc: stmt.loc,
            owner: ctx.owner,
            message: `assignment to '${stmt.target}' may not match declared/inferred type '${current.raw}'`,
          });
        }
        if (current.kind === "unknown" && valueType.kind !== "unknown" && valueType.kind !== "null") {
          ctx.bindings.set(stmt.target, valueType);
        }
      }
      return;
    }
    case "append": {
      checkShadowing(stmt.target, stmt.loc, ctx);
      const valueType = inferExpressionType(stmt.value, ctx);
      if (!isCompatibleKind(valueType.kind, "jsonb") && valueType.kind !== "unknown") {
        ctx.warnings.push({
          code: "type.append-non-jsonb",
          hint: "Only append jsonb values to jsonb arrays or cast the value before appending.",
          loc: stmt.loc,
          owner: ctx.owner,
          message: `append on '${stmt.target}' expects jsonb-compatible values`,
        });
      }
      ctx.bindings.set(stmt.target, declaredType("jsonb"));
      return;
    }
    case "if": {
      expectBooleanLike(
        stmt.condition,
        stmt.loc,
        "type.non-boolean-condition",
        "Use a boolean expression in the if condition.",
        ctx,
      );
      analyzeStatements(stmt.body, nestedContext(stmt.body, ctx));
      for (const elsif of stmt.elsifs) {
        expectBooleanLike(
          elsif.condition,
          elsif.condition.loc,
          "type.non-boolean-condition",
          "Use a boolean expression in the elsif condition.",
          ctx,
        );
        analyzeStatements(elsif.body, nestedContext(elsif.body, ctx));
      }
      if (stmt.elseBody) analyzeStatements(stmt.elseBody, nestedContext(stmt.elseBody, ctx));
      return;
    }
    case "for_in": {
      const nested = nestedContext(stmt.body, ctx);
      nested.bindings.set(stmt.variable, declaredType("record"));
      nested.knownNames.add(stmt.variable);
      analyzeStatements(stmt.body, nested);
      return;
    }
    case "return": {
      const valueType = inferExpressionType(stmt.value, ctx);
      maybeAnalyzeSqlBlock(stmt.value, stmt.loc, ctx);
      if (stmt.mode === "execute") {
        addDynamicSqlWarnings(stmt.value, stmt.loc, ctx);
        return;
      }
      if (
        ctx.returnType.kind !== "unknown" &&
        ctx.returnType.kind !== "void" &&
        valueType.kind !== "unknown" &&
        valueType.kind !== "null"
      ) {
        if (!typesCompatible(ctx.returnType, valueType)) {
          ctx.warnings.push({
            code: "type.return-mismatch",
            hint: `Return a value compatible with '${ctx.returnType.raw}' or cast it explicitly.`,
            loc: stmt.loc,
            owner: ctx.owner,
            message: `return type '${valueType.raw}' may not match declared return type '${ctx.returnType.raw}'`,
          });
        }
      }
      return;
    }
    case "raise":
      return;
    case "match": {
      const subjectType = inferExpressionType(stmt.subject, ctx);
      for (const arm of stmt.arms) {
        const patternType = inferExpressionType(arm.pattern, ctx);
        if (
          subjectType.kind !== "unknown" &&
          patternType.kind !== "unknown" &&
          !typesCompatible(subjectType, patternType)
        ) {
          ctx.warnings.push({
            code: "type.match-pattern-mismatch",
            hint: "Use patterns compatible with the match subject type.",
            loc: arm.pattern.loc,
            owner: ctx.owner,
            message: `match pattern '${patternType.raw}' may not be compatible with subject type '${subjectType.raw}'`,
          });
        }
        analyzeStatements(arm.body, nestedContext(arm.body, ctx));
      }
      if (stmt.elseBody) analyzeStatements(stmt.elseBody, nestedContext(stmt.elseBody, ctx));
      return;
    }
    case "sql_statement":
      analyzeSqlText(stmt.sql, stmt.loc, ctx);
      return;
    case "assert":
      expectBooleanLike(
        stmt.expression,
        stmt.loc,
        "type.non-boolean-assert",
        "Assert expects a boolean expression.",
        ctx,
      );
      return;
  }
}

function inferExpressionType(expr: Expression, ctx: AnalysisContext): TypeInfo {
  switch (expr.kind) {
    case "identifier":
      if (ctx.importAliases.has(expr.name)) {
        ctx.usedImports.add(expr.name);
      }
      if (!ctx.knownNames.has(expr.name) && !ctx.importAliases.has(expr.name) && !RESERVED_IDENTIFIERS.has(expr.name)) {
        ctx.errors.push({
          code: "semantic.unknown-identifier",
          hint: "Declare the variable first or import the function alias you want to use.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `unknown identifier '${expr.name}'`,
        });
      }
      return (
        ctx.bindings.get(expr.name) ??
        (expr.name === "null" ? declaredType("null") : { kind: "unknown", raw: "unknown" })
      );
    case "field_access": {
      const root = expr.object.split(".")[0] ?? expr.object;
      if (!ctx.knownNames.has(root) && !RESERVED_IDENTIFIERS.has(root)) {
        ctx.errors.push({
          code: "semantic.unknown-identifier",
          hint: "Declare the source variable before accessing one of its fields.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `unknown identifier '${root}'`,
        });
        return { kind: "unknown", raw: "unknown" };
      }
      const rootType = ctx.bindings.get(root) ?? { kind: "unknown", raw: "unknown" };
      if (!isOneOf(rootType.kind, ["jsonb", "record", "unknown"])) {
        ctx.warnings.push({
          code: "type.invalid-field-access",
          hint: "Use '.' access on record-like values only.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `field access on '${root}' may be invalid for type '${rootType.raw}'`,
        });
      }
      return { kind: "unknown", raw: "unknown" };
    }
    case "call":
      return inferCallType(expr, ctx);
    case "binary":
      return inferBinaryType(expr, ctx);
    case "unary":
      return inferUnaryType(expr, ctx);
    case "group":
      return inferExpressionType(expr.expression, ctx);
    case "case_expr":
      inferExpressionType(expr.subject, ctx);
      for (const arm of expr.arms) {
        inferExpressionType(arm.pattern, ctx);
      }
      return combineTypes(
        expr.arms
          .map((arm) => inferExpressionType(arm.result, ctx))
          .concat(expr.elseResult ? inferExpressionType(expr.elseResult, ctx) : []),
      );
    case "array_literal":
      for (const element of expr.elements) inferExpressionType(element, ctx);
      return declaredType("jsonb");
    case "json_literal":
      for (const entry of expr.entries) inferExpressionType(entry.value, ctx);
      return declaredType("jsonb");
    case "string_interp":
      for (const part of expr.parts) {
        if (typeof part !== "string") inferExpressionType(part, ctx);
      }
      return declaredType("text");
    case "literal":
      return declaredType(expr.type);
    case "sql_block":
      analyzeSqlText(expr.sql, expr.loc, ctx);
      return inferSqlType(expr.sql);
  }
}

function inferCallType(expr: Extract<Expression, { kind: "call" }>, ctx: AnalysisContext): TypeInfo {
  const callRoot = expr.name.split(".")[0] ?? expr.name;
  const targetName = ctx.importTargets.get(callRoot) ?? expr.name;
  if (ctx.importAliases.has(callRoot)) ctx.usedImports.add(callRoot);

  const argTypes = expr.args.map((arg) => inferExpressionType(arg, ctx));
  const builtin = builtinSignature(targetName);
  if (!builtin) return { kind: "unknown", raw: "unknown" };

  if (builtin.minArgs !== undefined && expr.args.length < builtin.minArgs) {
    ctx.warnings.push({
      code: "type.call-arity-mismatch",
      hint: builtin.hint ?? `Expected at least ${builtin.minArgs} arguments.`,
      loc: expr.loc,
      owner: ctx.owner,
      message: `call to '${targetName}' expects at least ${builtin.minArgs} arguments`,
    });
  }
  if (builtin.maxArgs !== undefined && expr.args.length > builtin.maxArgs) {
    ctx.warnings.push({
      code: "type.call-arity-mismatch",
      hint: builtin.hint ?? `Expected at most ${builtin.maxArgs} arguments.`,
      loc: expr.loc,
      owner: ctx.owner,
      message: `call to '${targetName}' expects at most ${builtin.maxArgs} arguments`,
    });
  }

  if (builtin.argKinds) {
    builtin.argKinds.forEach((kind, index) => {
      const actual = argTypes[index];
      if (!actual || kind === "unknown" || actual.kind === "unknown") return;
      if (!isCompatibleKind(actual.kind, kind)) {
        ctx.warnings.push({
          code: "type.call-argument-mismatch",
          hint: builtin.hint ?? `Pass a ${kind} argument to '${targetName}'.`,
          loc: expr.args[index]?.loc ?? expr.loc,
          owner: ctx.owner,
          message: `argument ${index + 1} of '${targetName}' should be ${kind}, got '${actual.raw}'`,
        });
      }
    });
  }

  if (targetName === "coalesce") {
    return combineTypes(argTypes);
  }
  if (targetName === "now" || targetName === "clock_timestamp") {
    return { kind: "unknown", raw: "timestamptz" };
  }
  return declaredType(builtin.returnType);
}

function inferBinaryType(expr: Extract<Expression, { kind: "binary" }>, ctx: AnalysisContext): TypeInfo {
  const left = inferExpressionType(expr.left, ctx);
  const right = expr.op === "::" ? inferCastTarget(expr.right) : inferExpressionType(expr.right, ctx);

  switch (expr.op) {
    case "AND":
    case "OR":
      if (!isOneOf(left.kind, ["boolean", "unknown"]) || !isOneOf(right.kind, ["boolean", "unknown"])) {
        ctx.warnings.push({
          code: "type.invalid-boolean-operator",
          hint: "Use boolean operands with AND/OR.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `operator '${expr.op}' expects boolean operands`,
        });
      }
      return declaredType("boolean");
    case "=":
    case "!=":
    case ">":
    case "<":
    case ">=":
    case "<=":
    case "IS NOT NULL":
      return declaredType("boolean");
    case "+":
    case "-":
    case "*":
    case "/":
      if (!isNumericLike(left.kind) || !isNumericLike(right.kind)) {
        ctx.warnings.push({
          code: "type.invalid-numeric-operator",
          hint: "Use numeric operands or cast values before applying arithmetic operators.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `operator '${expr.op}' expects numeric operands`,
        });
      }
      return combineNumeric(left, right);
    case "||":
      if (left.kind === "jsonb" && right.kind === "jsonb") return declaredType("jsonb");
      return declaredType("text");
    case "->":
      if (!isOneOf(left.kind, ["jsonb", "record", "unknown"])) {
        ctx.warnings.push({
          code: "type.invalid-json-access",
          hint: "Use '->' on jsonb values or cast the source expression to jsonb first.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `operator '->' expects a jsonb-like left operand`,
        });
      }
      return declaredType("jsonb");
    case "->>":
      if (!isOneOf(left.kind, ["jsonb", "record", "unknown"])) {
        ctx.warnings.push({
          code: "type.invalid-json-access",
          hint: "Use '->>' on jsonb values or cast the source expression to jsonb first.",
          loc: expr.loc,
          owner: ctx.owner,
          message: `operator '->>' expects a jsonb-like left operand`,
        });
      }
      return declaredType("text");
    case "::":
      return right.kind === "unknown" ? { kind: "unknown", raw: "unknown" } : right;
    default:
      return { kind: "unknown", raw: "unknown" };
  }
}

function inferUnaryType(expr: Extract<Expression, { kind: "unary" }>, ctx: AnalysisContext): TypeInfo {
  const inner = inferExpressionType(expr.expression, ctx);
  if (expr.op === "NOT") {
    if (!isOneOf(inner.kind, ["boolean", "unknown"])) {
      ctx.warnings.push({
        code: "type.invalid-boolean-operator",
        hint: "Use NOT with a boolean expression.",
        loc: expr.loc,
        owner: ctx.owner,
        message: "operator 'NOT' expects a boolean operand",
      });
    }
    return declaredType("boolean");
  }

  if (!isNumericLike(inner.kind)) {
    ctx.warnings.push({
      code: "type.invalid-numeric-operator",
      hint: "Use unary +/- with numeric values only.",
      loc: expr.loc,
      owner: ctx.owner,
      message: `operator '${expr.op}' expects a numeric operand`,
    });
  }
  return inner.kind === "numeric" ? inner : declaredType("int");
}

function expectBooleanLike(expr: Expression, loc: Loc, code: string, hint: string, ctx: AnalysisContext): void {
  const type = inferExpressionType(expr, ctx);
  if (type.kind !== "unknown" && type.kind !== "boolean") {
    ctx.warnings.push({
      code,
      hint,
      loc,
      owner: ctx.owner,
      message: `expected a boolean expression, got '${type.raw}'`,
    });
  }
}

function maybeAnalyzeSqlBlock(expr: Expression, loc: Loc, ctx: AnalysisContext): void {
  if (expr.kind === "sql_block") analyzeSqlText(expr.sql, loc, ctx);
}

function analyzeSqlText(sql: string, loc: Loc, ctx: AnalysisContext): void {
  const normalized = sql.replace(/\s+/g, " ").trim().toLowerCase();
  if ((normalized.startsWith("update ") || normalized.startsWith("delete from ")) && !normalized.includes(" where ")) {
    ctx.warnings.push({
      code: "sql.dml-without-where",
      hint: "Add an explicit WHERE clause or a guard proving the statement is intentionally unscoped.",
      loc,
      owner: ctx.owner,
      message: "UPDATE/DELETE statement without WHERE clause",
    });
  }
}

function addDynamicSqlWarnings(expr: Expression, loc: Loc, ctx: AnalysisContext): void {
  ctx.warnings.push({
    code: "sql.dynamic-execute",
    hint: "Prefer static SQL when possible, or use format(...)/USING with carefully bound values.",
    loc,
    owner: ctx.owner,
    message: "RETURN QUERY EXECUTE uses dynamic SQL",
  });

  if (isDynamicStringConstruction(expr)) {
    ctx.warnings.push({
      code: "sql.dynamic-execute-concat",
      hint: "Avoid SQL string concatenation/interpolation in EXECUTE; prefer format() plus USING parameters.",
      loc,
      owner: ctx.owner,
      message: "dynamic SQL is built from concatenation or interpolation",
    });
  }
}

function isDynamicStringConstruction(expr: Expression): boolean {
  switch (expr.kind) {
    case "string_interp":
      return true;
    case "binary":
      return expr.op === "||" || isDynamicStringConstruction(expr.left) || isDynamicStringConstruction(expr.right);
    case "group":
      return isDynamicStringConstruction(expr.expression);
    default:
      return false;
  }
}

function nestedContext(stmts: Statement[], ctx: AnalysisContext): AnalysisContext {
  return {
    ...ctx,
    bindings: new Map(ctx.bindings),
    knownNames: new Set<string>([...ctx.knownNames, ...collectLocals(stmts)]),
  };
}

function builtinSignature(
  name: string,
): { argKinds?: TypeKind[]; hint?: string; maxArgs?: number; minArgs?: number; returnType: string } | undefined {
  switch (name) {
    case "upper":
    case "lower":
    case "trim":
      return { argKinds: ["text"], maxArgs: 1, minArgs: 1, returnType: "text" };
    case "count":
      return { maxArgs: 1, minArgs: 1, returnType: "numeric" };
    case "sum":
      return { argKinds: ["numeric"], maxArgs: 1, minArgs: 1, returnType: "numeric" };
    case "jsonb_build_object":
      return {
        hint: "Pass an even number of key/value arguments to jsonb_build_object.",
        minArgs: 0,
        returnType: "jsonb",
      };
    case "jsonb_build_array":
    case "row_to_json":
    case "to_jsonb":
      return { minArgs: 0, returnType: "jsonb" };
    case "format":
    case "concat":
      return { minArgs: 1, returnType: "text" };
    case "coalesce":
      return { minArgs: 2, returnType: "unknown" };
    case "now":
    case "clock_timestamp":
      return { maxArgs: 0, minArgs: 0, returnType: "unknown" };
    default:
      return undefined;
  }
}

function inferCastTarget(expr: Expression): TypeInfo {
  if (expr.kind === "identifier") return declaredType(expr.name);
  if (expr.kind === "field_access") return declaredType(`${expr.object}.${expr.field}`);
  return { kind: "unknown", raw: "unknown" };
}

function inferSqlType(sql: string): TypeInfo {
  const normalized = sql.toLowerCase().trim();
  if (normalized.startsWith("(") && normalized.endsWith(")")) {
    return inferSqlType(normalized.slice(1, -1).trim());
  }
  if (/^select\s+count\s*\(/.test(normalized)) return declaredType("numeric");
  if (/^select\s+(?:to_jsonb|jsonb_build_object|jsonb_build_array|jsonb_agg)\s*\(/.test(normalized)) {
    return declaredType("jsonb");
  }
  if (/^select\s+(?:true|false)\b/.test(normalized)) return declaredType("boolean");
  if (/^select\s+\d+/.test(normalized)) return declaredType("int");
  if (/^select\s+'/.test(normalized)) return declaredType("text");
  if (/(?:insert\s+into|update|delete\s+from).*\breturning\s+\*/.test(normalized)) return declaredType("record");
  return { kind: "unknown", raw: "unknown" };
}

function declaredType(raw: string): TypeInfo {
  const type = raw.toLowerCase();
  if (type === "boolean" || type === "bool") return { kind: "boolean", raw };
  if (type === "int" || type === "integer" || type === "bigint" || type === "smallint") return { kind: "int", raw };
  if (type === "numeric" || type === "decimal" || type === "float" || type === "double precision") {
    return { kind: "numeric", raw };
  }
  if (type === "json" || type === "jsonb") return { kind: "jsonb", raw };
  if (type === "text" || type === "varchar" || type === "char" || type === "character varying") {
    return { kind: "text", raw };
  }
  if (type === "null") return { kind: "null", raw };
  if (type === "void") return { kind: "void", raw };
  if (type.includes(".")) return { kind: "record", raw };
  return { kind: "unknown", raw };
}

function combineTypes(types: TypeInfo[]): TypeInfo {
  const concrete = types.filter((type) => type.kind !== "null" && type.kind !== "unknown");
  if (concrete.length === 0) return { kind: "unknown", raw: "unknown" };
  const first = concrete[0];
  if (!first) return { kind: "unknown", raw: "unknown" };
  if (concrete.every((type) => typesCompatible(first, type))) return first;
  return { kind: "unknown", raw: "unknown" };
}

function combineNumeric(left: TypeInfo, right: TypeInfo): TypeInfo {
  if (left.kind === "numeric" || right.kind === "numeric") return declaredType("numeric");
  return declaredType("int");
}

function typesCompatible(expected: TypeInfo, actual: TypeInfo): boolean {
  if (expected.kind === "unknown" || actual.kind === "unknown" || actual.kind === "null") return true;
  if (expected.kind === actual.kind) return true;
  if (isNumericLike(expected.kind) && isNumericLike(actual.kind)) return true;
  return false;
}

function isCompatibleKind(actual: TypeKind, expected: TypeKind): boolean {
  return typesCompatible({ kind: expected, raw: expected }, { kind: actual, raw: actual });
}

function isNumericLike(kind: TypeKind): boolean {
  return NUMERIC_KINDS.has(kind);
}

function isOneOf(kind: TypeKind, allowed: TypeKind[]): boolean {
  return allowed.includes(kind);
}

function collectLocals(stmts: Statement[]): Set<string> {
  const locals = new Set<string>();
  walkStatements(stmts, {
    onStatement(stmt) {
      if (stmt.kind === "assign" && stmt.target !== "_") locals.add(stmt.target);
      if (stmt.kind === "append") locals.add(stmt.target);
      if (stmt.kind === "for_in") locals.add(stmt.variable);
    },
  });
  return locals;
}

function checkDuplicates(
  entries: { loc: Loc; name: string }[],
  owner: string,
  label: string,
  code: string,
  hint: string,
  errors: SemanticIssue[],
): void {
  const seen = new Set<string>();
  for (const entry of entries) {
    if (seen.has(entry.name)) {
      errors.push({
        code,
        hint,
        loc: entry.loc,
        owner,
        message: `duplicate ${label} '${entry.name}'`,
      });
      continue;
    }
    seen.add(entry.name);
  }
}

function checkShadowing(name: string, loc: Loc, ctx: AnalysisContext): void {
  if (!ctx.importAliases.has(name)) return;
  ctx.errors.push({
    code: "semantic.shadowed-import-alias",
    hint: "Rename the local variable or the import alias to keep names unambiguous.",
    loc,
    owner: ctx.owner,
    message: `local name '${name}' shadows import alias '${name}'`,
  });
}

export function inferredLoc(stmts: Statement[]): Loc {
  return stmts[0]?.loc ?? pointLoc();
}
