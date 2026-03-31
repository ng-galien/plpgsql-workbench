/** Escape single quotes for PL/pgSQL string literals: ' → '' */
export function sqlEscape(s: string): string {
  return s.replace(/'/g, "''");
}
