import { PlUri, type ResourceKind } from "../../uri.js";

export type PlpgsqlTarget =
  | { kind: "catalog"; uri: string }
  | { kind: "doc_index"; uri: string }
  | { kind: "doc_topic"; uri: string; topic: string }
  | { kind: "schema"; uri: string; schema: string }
  | { kind: "resource"; uri: string; schema: string; resourceKind: ResourceKind; name: string }
  | { kind: "glob"; uri: string; schema: string; resourceKind: ResourceKind }
  | { kind: "invalid"; uri: string; problem: string };

export function resolvePlpgsqlTarget(uri: string): PlpgsqlTarget {
  const trimmed = uri.trim();

  if (trimmed === "plpgsql://" || trimmed === "plpgsql://catalog") {
    return { kind: "catalog", uri: trimmed };
  }

  const docTopicMatch = trimmed.match(/^plpgsql:\/\/workbench\/doc\/(.+)$/);
  const docTopic = docTopicMatch?.[1];
  if (docTopic) {
    return { kind: "doc_topic", uri: trimmed, topic: docTopic };
  }

  if (trimmed === "plpgsql://workbench/doc" || trimmed === "plpgsql://workbench") {
    return { kind: "doc_index", uri: trimmed };
  }

  const globMatch = trimmed.match(/^plpgsql:\/\/(\w+)\/(\w+)\/\*$/);
  if (globMatch) {
    const schema = globMatch[1];
    const resourceKind = globMatch[2];
    const resolvedKind = resourceKind ?? "";
    if (schema && isResourceKind(resolvedKind)) {
      return { kind: "glob", uri: trimmed, schema, resourceKind: resolvedKind };
    }
    return { kind: "invalid", uri: trimmed, problem: `invalid resource kind: ${resolvedKind}` };
  }

  const parsed = PlUri.parse(trimmed);
  if (!parsed) {
    return { kind: "invalid", uri: trimmed, problem: `invalid URI: ${trimmed}` };
  }

  if (!parsed.kind) {
    return { kind: "schema", uri: trimmed, schema: parsed.schema };
  }

  if (parsed.name) {
    return {
      kind: "resource",
      uri: trimmed,
      schema: parsed.schema,
      resourceKind: parsed.kind,
      name: parsed.name,
    };
  }

  return { kind: "invalid", uri: trimmed, problem: `invalid URI: ${trimmed}` };
}

function isResourceKind(value: string): value is ResourceKind {
  return value === "function" || value === "table" || value === "trigger" || value === "type";
}
