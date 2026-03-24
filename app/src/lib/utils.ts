import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
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
