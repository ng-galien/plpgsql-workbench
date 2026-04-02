export function formatDefaultValue(value: string, type: string): string {
  const lowerType = type.toLowerCase();

  if (value.includes("(") || value.includes("::") || value === "true" || value === "false" || value === "null") {
    return value;
  }

  if (/^(int|integer|bigint|smallint|numeric|decimal|float|double|serial|real)/.test(lowerType)) {
    return value;
  }

  return `'${value.replace(/'/g, "''")}'`;
}
