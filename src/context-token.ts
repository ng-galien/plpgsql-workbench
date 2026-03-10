/**
 * Context token — stateless proof that an agent has read a function
 * and its dependency neighborhood before modifying it.
 *
 * Token = HMAC(body_hash | callee_body_hashes | caller_names, secret)
 *
 * The secret is per-process: tokens expire on server restart,
 * forcing a re-read. This is correct behavior.
 */

import crypto from "crypto";
import type { DbClient } from "./connection.js";

// Per-process secret — tokens expire on server restart
const SECRET = crypto.randomUUID();

function hmac(payload: string): string {
  return crypto.createHmac("sha256", SECRET).update(payload).digest("hex").slice(0, 24);
}

/**
 * Compute a context token for a function.
 * Encodes: body hash + callee body hashes + caller names.
 * Returns null if function doesn't exist.
 */
export async function computeContextToken(
  client: DbClient,
  schema: string,
  name: string,
): Promise<string | null> {
  const { rows } = await client.query<{ prosrc: string }>(
    `SELECT p.prosrc FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_language l ON l.oid = p.prolang
     WHERE n.nspname = $1 AND p.proname = $2 AND l.lanname IN ('sql', 'plpgsql')
     LIMIT 1`,
    [schema, name],
  );
  if (rows.length === 0) return null;

  const bodyHash = crypto.createHash("md5").update(rows[0].prosrc).digest("hex");

  // Extract schema-qualified calls from body
  const calls: string[] = [];
  const re = /\b(\w+)\.(\w+)\s*\(/g;
  let m;
  while ((m = re.exec(rows[0].prosrc)) !== null) {
    const qname = `${m[1]}.${m[2]}`;
    if (!calls.includes(qname)) calls.push(qname);
  }

  // Get callee body hashes in one query
  let calleeKey = "";
  if (calls.length > 0) {
    const { rows: calleeRows } = await client.query<{ h: string }>(
      `SELECT md5(p.prosrc) AS h
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname || '.' || p.proname = ANY($1)
       ORDER BY n.nspname, p.proname`,
      [calls],
    );
    calleeKey = calleeRows.map((r) => r.h).join(",");
  }

  // Get caller names — escape function name for safe regex use
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  // Scope to the same schema family (base + _ut/_it/_qa) to avoid false positives
  const schemaBase = schema.replace(/_(ut|it|qa)$/, "");
  const schemaPattern = `^${schemaBase}(_ut|_it|_qa)?$`;
  const { rows: callerRows } = await client.query<{ caller: string }>(
    `SELECT n.nspname || '.' || p.proname AS caller
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname ~ $4
       AND p.prosrc ~ $1
       AND NOT (n.nspname = $2 AND p.proname = $3)
     ORDER BY caller`,
    [`\\m${escapedName}\\M`, schema, name, schemaPattern],
  );
  const callerKey = callerRows.map((r) => r.caller).join(",");

  return hmac(`${bodyHash}|${calleeKey}|${callerKey}`);
}

/**
 * Validate a context token. Returns { valid, reason }.
 * If the function doesn't exist yet (first deploy), validation passes.
 */
export async function validateContextToken(
  client: DbClient,
  schema: string,
  name: string,
  token: string | undefined,
): Promise<{ valid: boolean; reason?: string }> {
  const current = await computeContextToken(client, schema, name);

  // Function doesn't exist → first deploy, no token needed
  if (current === null) return { valid: true };

  // Function exists but no token provided → must read first
  if (!token) {
    return {
      valid: false,
      reason:
        `context_token requis pour modifier ${schema}.${name}.\n` +
        `Lis la fonction avec pg_get plpgsql://${schema}/function/${name} d'abord.`,
    };
  }

  // Token matches → context is current
  if (current === token) return { valid: true };

  // Token mismatch → context is stale
  return {
    valid: false,
    reason:
      `context_token perime pour ${schema}.${name}.\n` +
      `La fonction ou ses dependances ont change depuis la derniere lecture.\n` +
      `Re-read avec pg_get plpgsql://${schema}/function/${name} avant de modifier.`,
  };
}
