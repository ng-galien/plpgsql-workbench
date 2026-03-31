import type { DbClient } from "./connection.js";
import { loadDocs } from "./docs.js";
import { wrap } from "./helpers.js";

let workbenchReady = false;

export async function ensureWorkbenchSchema(client: DbClient): Promise<void> {
  if (workbenchReady) return;
  await client.query(`CREATE SCHEMA IF NOT EXISTS workbench`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.doc (
      topic text PRIMARY KEY,
      content text NOT NULL
    )
  `);
  for (const doc of loadDocs()) {
    await client.query(
      `INSERT INTO workbench.doc (topic, content) VALUES ($1, $2)
       ON CONFLICT (topic) DO UPDATE SET content = EXCLUDED.content`,
      [doc.topic, doc.content],
    );
  }
  workbenchReady = true;
}

export async function resolveDoc(client: DbClient, topic: string): Promise<string> {
  await ensureWorkbenchSchema(client);
  const { rows } = await client.query<{ content: string }>(`SELECT content FROM workbench.doc WHERE topic = $1`, [
    topic,
  ]);
  if (rows.length === 0) return `doc "${topic}" not found`;
  return wrap(`plpgsql://workbench/doc/${topic}`, "full", rows[0]!.content, [`get plpgsql://workbench/doc`]);
}

export async function resolveDocIndex(client: DbClient): Promise<string> {
  await ensureWorkbenchSchema(client);
  const { rows } = await client.query<{ topic: string }>(`SELECT topic FROM workbench.doc ORDER BY topic`);
  if (rows.length === 0) return wrap("plpgsql://workbench/doc", "full", "no docs yet", []);
  const lines = rows.map((r) => `  ${r.topic}  plpgsql://workbench/doc/${r.topic}`);
  return wrap("plpgsql://workbench/doc", "full", `docs:\n${lines.join("\n")}`, []);
}
