/** SQL identifier quoting (prevents injection in dynamic DDL). */
export function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

/** SQL literal quoting (prevents injection in dynamic values). */
export function quoteLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}
