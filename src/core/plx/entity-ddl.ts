import type { EntityField, PlxEntity } from "./ast.js";
import { formatDefaultValue } from "./entity-sql.js";

// ---------- Public types ----------

export interface DdlArtifact {
  key: string;
  name: string;
  sql: string;
  dependsOn: string[];
}

export interface ResolvedEntityFields {
  all: EntityField[];
  columns: EntityField[];
  payload: EntityField[];
}

// ---------- DDL generation ----------

export function generateDDL(entity: PlxEntity, resolved: ResolvedEntityFields): { artifacts: DdlArtifact[] } {
  const lines: string[] = [];
  lines.push(`CREATE TABLE IF NOT EXISTS ${entity.table} (`);
  lines.push("  id serial PRIMARY KEY,");

  for (const f of resolved.columns) {
    let col = `  ${f.name} ${f.type}`;
    if (!f.nullable) col += " NOT NULL";
    if (f.unique) col += " UNIQUE";
    if (f.defaultValue) col += ` DEFAULT ${formatDefaultValue(f.defaultValue, f.type)}`;
    col += ",";
    lines.push(col);
  }

  // State column CHECK constraint
  const states = entity.states;
  if (states) {
    const vals = states.values.map((v) => `'${v}'`).join(", ");
    // Add state column CHECK if not already in fields
    // Only add if status is not already in fields
    if (!resolved.columns.some((f) => f.name === states.column)) {
      lines.push(`  ${states.column} text NOT NULL DEFAULT '${states.initial}' CHECK (${states.column} IN (${vals})),`);
    }
  }

  if (entity.storage === "hybrid") {
    lines.push("  payload jsonb NOT NULL DEFAULT '{}'::jsonb,");
  }

  // Remove trailing comma from last line
  const lastLine = lines.at(-1) ?? "";
  lines[lines.length - 1] = lastLine.replace(/,$/, "");

  lines.push(");");

  const artifacts: DdlArtifact[] = [
    {
      key: `ddl:table:${entity.table}`,
      name: entity.table,
      sql: lines.join("\n"),
      dependsOn: [`ddl:schema:${entity.schema}`],
    },
  ];

  for (const field of resolved.columns) {
    if (!field.ref) continue;
    const constraintName = `${entity.name}_${field.name}_fkey`;
    artifacts.push({
      key: `ddl:fk:${entity.table}.${field.name}`,
      name: `${entity.table}.${field.name}`,
      sql:
        `ALTER TABLE ${entity.table} DROP CONSTRAINT IF EXISTS ${constraintName};\n` +
        `ALTER TABLE ${entity.table} ADD CONSTRAINT ${constraintName} FOREIGN KEY (${field.name}) REFERENCES ${field.ref}(id);`,
      dependsOn: [`ddl:table:${entity.table}`, `ddl:table:${field.ref}`],
    });
  }

  artifacts.push({
    key: `ddl:grant:${entity.table}`,
    name: `${entity.table}.grant`,
    sql: `GRANT USAGE ON SCHEMA ${entity.schema} TO anon;\nGRANT SELECT ON TABLE ${entity.table} TO anon;`,
    dependsOn: [`ddl:table:${entity.table}`],
  });

  return { artifacts };
}
