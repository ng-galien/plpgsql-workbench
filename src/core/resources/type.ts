import type { DbClient } from "../connection.js";

export interface TypeDetail {
  name: string;
  schema: string;
  kind: "composite" | "enum";
  attributes?: { name: string; type: string }[];
  values?: string[];
  used_by: string[];
}

// --- Query ---

export async function queryType(client: DbClient, schema: string, name: string): Promise<TypeDetail | null> {
  // Composite
  const compResult = await client.query<{ attname: string; typname: string }>(
    `
    SELECT a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod) AS typname
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_attribute a ON a.attrelid = t.typrelid
    WHERE n.nspname = $1 AND t.typname = $2
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
  `,
    [schema, name],
  );

  if (compResult.rows.length > 0) {
    const used_by = await findTypeUsers(client, name);
    return {
      name,
      schema,
      kind: "composite",
      attributes: compResult.rows.map((r) => ({ name: r.attname, type: r.typname })),
      used_by,
    };
  }

  // Enum
  const enumResult = await client.query<{ enumlabel: string }>(
    `
    SELECT e.enumlabel
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE n.nspname = $1 AND t.typname = $2
    ORDER BY e.enumsortorder
  `,
    [schema, name],
  );

  if (enumResult.rows.length > 0) {
    const used_by = await findTypeUsers(client, name);
    return {
      name,
      schema,
      kind: "enum",
      values: enumResult.rows.map((r) => r.enumlabel),
      used_by,
    };
  }

  return null;
}

async function findTypeUsers(client: DbClient, typeName: string): Promise<string[]> {
  const { rows } = await client.query<{ user_name: string }>(
    `
    SELECT n.nspname || '.' || p.proname AS user_name
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.prosrc ~* $1
    ORDER BY user_name
  `,
    [`\\m${typeName}\\M`],
  );
  return rows.map((r) => r.user_name);
}

// --- Format ---

export function formatType(type: TypeDetail): string {
  const parts: string[] = [];

  if (type.kind === "composite") {
    parts.push(`${type.schema}.${type.name} (composite)`);
    if (type.attributes) {
      const nameW = Math.max(...type.attributes.map((a) => a.name.length));
      for (const attr of type.attributes) {
        parts.push(`  ${attr.name.padEnd(nameW + 2)}${attr.type}`);
      }
    }
  } else {
    parts.push(`${type.schema}.${type.name} (enum)`);
    if (type.values) {
      parts.push(`  values: ${type.values.join(", ")}`);
    }
  }

  if (type.used_by.length > 0) {
    parts.push(`  used_by: ${type.used_by.join(", ")}`);
  }

  return parts.join("\n");
}
