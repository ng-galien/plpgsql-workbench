import type { FormField, ViewField, ViewTemplate } from "./store";
import { fieldKey } from "./utils";

export interface SduiActionNode {
  type: "action";
  label: string;
  verb: string;
  uri: string;
  variant?: string;
  confirm?: string;
}

export type SduiField = ViewField;

export type SduiNode =
  | { type: "column"; children: SduiNode[] }
  | { type: "row"; children: SduiNode[] }
  | { type: "section"; label: string; children: SduiNode[] }
  | { type: "field"; field: FormField }
  | { type: "heading"; text: string; level?: number }
  | { type: "text"; value: string }
  | { type: "badge"; text: string; variant?: string }
  | { type: "color"; value: string }
  | { type: "md"; content: string }
  | { type: "stat"; value: string; label: string; variant?: string }
  | { type: "currency"; amount: number; currency?: string }
  | { type: "workflow"; states: string[]; current: string }
  | {
      type: "timeline";
      events: Array<{ date: string; label: string; variant?: string; icon?: string }>;
    }
  | { type: "detail"; source: string; fields: SduiField[] }
  | {
      type: "table";
      source: string;
      columns: Array<{ key: string; label: string; type?: string; align?: string }>;
    }
  | {
      type: "line_items";
      source: string;
      columns: Array<{ key: string; label: string; type?: string; align?: string }>;
      totals?: Record<string, number | undefined>;
    }
  | SduiActionNode;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isSduiNode(value: unknown): value is SduiNode {
  return isRecord(value) && typeof value.type === "string";
}

function isSduiLevelMap(value: unknown): value is Partial<Record<"compact" | "standard" | "expanded", SduiNode>> {
  if (!isRecord(value)) return false;
  return ["compact", "standard", "expanded"].some((level) => isSduiNode(value[level]));
}

function normalizeArray(value: unknown): SduiNode[] {
  if (!Array.isArray(value)) return [];
  return value.filter(isSduiNode);
}

export function getSduiRoot(
  data: Record<string, unknown>,
  view: ViewTemplate | null,
  level: "compact" | "standard" | "expanded",
): SduiNode | null {
  const maybeUi = data.ui;
  if (isSduiNode(maybeUi)) return maybeUi;
  if (isSduiLevelMap(maybeUi)) {
    return maybeUi[level] ?? maybeUi.standard ?? maybeUi.compact ?? maybeUi.expanded ?? null;
  }

  const template = view?.template;
  if (!template) return null;

  const chosen =
    level === "expanded"
      ? (template.expanded ?? template.standard ?? template.compact)
      : level === "compact"
        ? (template.compact ?? template.standard)
        : (template.standard ?? template.compact);

  if (!chosen) return null;

  const children: SduiNode[] = [];
  if ("fields" in chosen && Array.isArray(chosen.fields) && chosen.fields.length > 0) {
    children.push({
      type: "detail",
      source: "self",
      fields: chosen.fields,
    });
  }

  if ("stats" in chosen && Array.isArray(chosen.stats) && chosen.stats.length > 0) {
    children.push({
      type: "row",
      children: chosen.stats.map((stat) => ({
        type: "stat",
        value: data[stat.key] == null ? "—" : String(data[stat.key]),
        label: stat.label,
        variant: stat.variant,
      })),
    });
  }

  if ("related" in chosen && Array.isArray(chosen.related) && chosen.related.length > 0) {
    children.push({
      type: "row",
      children: chosen.related.map((rel) => ({
        type: "badge",
        text: rel.label,
        variant: "outline",
      })),
    });
  }

  if (children.length === 0) return null;
  return { type: "column", children };
}

export function getSduiActions(view: ViewTemplate | null, data: Record<string, unknown>): SduiActionNode[] {
  const catalog = view?.actions ?? {};
  const raw = Array.isArray(data.actions) ? data.actions : [];
  const actions: Array<SduiActionNode | null> = raw.map((action) => {
    if (!isRecord(action)) return null;
    const verb = typeof action.method === "string" ? action.method : null;
    const uri = typeof action.uri === "string" ? action.uri : null;
    if (!verb || !uri) return null;
    const meta = catalog[verb];
    return {
      type: "action" as const,
      label: meta?.label ?? verb,
      verb,
      uri,
      variant: meta?.variant,
      confirm: meta?.confirm,
    };
  });
  return actions.filter((action): action is SduiActionNode => action !== null);
}

export function getSduiFormRoot(view: ViewTemplate | null): SduiNode | null {
  const sections = view?.template?.form?.sections;
  if (!sections || sections.length === 0) return null;

  return {
    type: "column",
    children: sections.map((section) => ({
      type: "section" as const,
      label: section.label,
      children: section.fields.map((field) => ({
        type: "field" as const,
        field,
      })),
    })),
  };
}

export function getSduiChildren(node: SduiNode): SduiNode[] {
  switch (node.type) {
    case "column":
    case "row":
    case "section":
      return node.children;
    default:
      return [];
  }
}

export function getSduiDataForSource(data: Record<string, unknown>, source: string): unknown {
  if (source === "self") return data;
  return data[source];
}

export function getSduiDetailFields(fields: SduiField[]): string[] {
  return fields.map((field) => fieldKey(field));
}

export function coerceSduiChildren(value: unknown): SduiNode[] {
  return normalizeArray(value);
}
