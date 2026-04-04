import { createToolFailure, type ToolFailure } from "./failure.js";
import { resolvePlpgsqlTarget } from "./target-resolution.js";

export interface PlpgsqlSchemaTarget {
  uri: string;
  schema: string;
}

export interface PlpgsqlFunctionTarget {
  uri: string;
  schema: string;
  name: string;
}

export type PlpgsqlSchemaOrFunctionTarget =
  | ({ kind: "schema" } & PlpgsqlSchemaTarget)
  | ({ kind: "function" } & PlpgsqlFunctionTarget);

type ValidationResult<T> = { ok: true; value: T } | { ok: false; failure: ToolFailure };

export function expectPlpgsqlSchemaTarget(uri: string, where: string): ValidationResult<PlpgsqlSchemaTarget> {
  const target = resolvePlpgsqlTarget(uri);
  if (target.kind === "schema") {
    return { ok: true, value: { uri: target.uri, schema: target.schema } };
  }

  return {
    ok: false,
    failure: createToolFailure(invalidTargetProblem(target, uri), where, {
      fixHint: "use plpgsql://schema",
    }),
  };
}

export function expectPlpgsqlFunctionTarget(uri: string, where: string): ValidationResult<PlpgsqlFunctionTarget> {
  const target = resolvePlpgsqlTarget(uri);
  if (target.kind === "resource" && target.resourceKind === "function") {
    return { ok: true, value: { uri: target.uri, schema: target.schema, name: target.name } };
  }

  return {
    ok: false,
    failure: createToolFailure(invalidTargetProblem(target, uri), where, {
      fixHint: "use plpgsql://schema/function/name",
    }),
  };
}

export function expectPlpgsqlSchemaOrFunctionTarget(
  uri: string,
  where: string,
): ValidationResult<PlpgsqlSchemaOrFunctionTarget> {
  const target = resolvePlpgsqlTarget(uri);
  if (target.kind === "schema") {
    return { ok: true, value: { kind: "schema", uri: target.uri, schema: target.schema } };
  }
  if (target.kind === "resource" && target.resourceKind === "function") {
    return { ok: true, value: { kind: "function", uri: target.uri, schema: target.schema, name: target.name } };
  }

  return {
    ok: false,
    failure: createToolFailure(invalidTargetProblem(target, uri), where, {
      fixHint: "use plpgsql://schema or plpgsql://schema/function/name",
    }),
  };
}

function invalidTargetProblem(target: ReturnType<typeof resolvePlpgsqlTarget>, fallbackUri: string): string {
  if (target.kind === "invalid") return target.problem;
  return `invalid target: ${target.uri || fallbackUri}`;
}
