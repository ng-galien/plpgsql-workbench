import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import type { ViewField } from "./store";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getDisplayName(row: Record<string, unknown>, fallback = "—"): string {
  return String(row.name ?? row.ref ?? row.id ?? fallback);
}

export function parseEntityUri(uri: string): { schema: string; entity: string; id?: string } {
  const [schema, path] = uri.split("://");
  if (!path) return { schema: "", entity: "" };
  const parts = path.split("/");
  return { schema, entity: parts[0], id: parts[1] };
}

export function buildEntityUri(schema: string, entity: string, id?: string): string {
  return id ? `${schema}://${entity}/${id}` : `${schema}://${entity}`;
}

export function fieldKey(f: ViewField): string {
  return typeof f === "string" ? f : f.key;
}

export function fieldType(f: ViewField): string | undefined {
  return typeof f === "string" ? undefined : f.type;
}

export function fieldLabel(f: ViewField): string | undefined {
  return typeof f === "string" ? undefined : f.label;
}

export function getCompactDisplayName(row: Record<string, unknown>, compactFields?: string[], fallback = "—"): string {
  const titleField = compactFields?.[0];
  if (titleField && row[titleField] != null) return String(row[titleField]);
  return getDisplayName(row, fallback);
}

export function resolveFieldLabel(
  key: string,
  viewUri: string | undefined,
  formSections: Array<{ fields: Array<{ key: string; label: string }> }> | undefined,
  t: (k: string) => string,
): string {
  if (formSections) {
    for (const section of formSections) {
      for (const field of section.fields) {
        if (field.key === key && field.label) return t(field.label);
      }
    }
  }
  const schema = viewUri?.split("://")[0];
  if (schema) {
    const i18nKey = `${schema}.field_${key}`;
    const resolved = t(i18nKey);
    if (resolved !== i18nKey) return resolved;
  }
  return key.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function formatDate(v: string): string {
  try {
    return new Date(v).toLocaleDateString();
  } catch {
    return v;
  }
}

export function formatDatetime(v: string): string {
  try {
    return new Date(v).toLocaleString(undefined, { dateStyle: "short", timeStyle: "short" });
  } catch {
    return v;
  }
}
