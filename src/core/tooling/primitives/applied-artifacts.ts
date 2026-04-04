import type { DbClient } from "../../connection.js";

export interface ArtifactLike<Kind extends string = string> {
  key: string;
  kind: Kind;
  name: string;
  hash: string;
}

export interface AppliedArtifactState<Kind extends string = string> extends ArtifactLike<Kind> {
  file?: string;
  appliedAt: string;
}

export interface AppliedArtifactDiff<
  TArtifact extends ArtifactLike<TKind>,
  TState extends AppliedArtifactState<TKind>,
  TKind extends string = string,
> {
  changed: TArtifact[];
  unchanged: TArtifact[];
  obsolete: TState[];
}

export interface AppliedArtifactRow<Kind extends string = string> {
  artifact_key: string;
  artifact_kind: Kind;
  artifact_name: string;
  artifact_hash: string;
  artifact_file: string | null;
  applied_at: string;
}

export interface AppliedArtifactTable {
  schema?: string;
  table: string;
  scopeColumn: string;
}

export interface AppliedArtifactScope extends AppliedArtifactTable {
  scopeValue: string;
}

export function diffAppliedArtifacts<
  TArtifact extends ArtifactLike<TKind>,
  TState extends AppliedArtifactState<TKind>,
  TKind extends string = string,
>(artifacts: TArtifact[], appliedState: Map<string, TState>): AppliedArtifactDiff<TArtifact, TState, TKind> {
  const changed: TArtifact[] = [];
  const unchanged: TArtifact[] = [];

  for (const artifact of artifacts) {
    const applied = appliedState.get(artifact.key);
    if (applied?.hash === artifact.hash) unchanged.push(artifact);
    else changed.push(artifact);
  }

  const currentKeys = new Set(artifacts.map((artifact) => artifact.key));
  const obsolete = [...appliedState.values()].filter((state) => !currentKeys.has(state.key));

  return { changed, unchanged, obsolete };
}

export function mapAppliedArtifactRows<Kind extends string = string>(
  rows: AppliedArtifactRow<Kind>[],
): Map<string, AppliedArtifactState<Kind>> {
  const states = new Map<string, AppliedArtifactState<Kind>>();
  for (const row of rows) {
    states.set(row.artifact_key, {
      key: row.artifact_key,
      kind: row.artifact_kind,
      name: row.artifact_name,
      hash: row.artifact_hash,
      file: row.artifact_file ?? undefined,
      appliedAt: row.applied_at,
    });
  }
  return states;
}

export async function ensureAppliedArtifactTable(client: DbClient, table: AppliedArtifactTable): Promise<void> {
  const schema = table.schema ?? "workbench";
  await client.query(`CREATE SCHEMA IF NOT EXISTS ${quoteIdent(schema)}`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${quoteIdent(schema)}.${quoteIdent(table.table)} (
      ${quoteIdent(table.scopeColumn)} text NOT NULL,
      artifact_key text NOT NULL,
      artifact_kind text NOT NULL,
      artifact_name text NOT NULL,
      artifact_file text,
      artifact_hash text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (${quoteIdent(table.scopeColumn)}, artifact_key)
    )
  `);
}

export async function readAppliedArtifactStates<Kind extends string = string>(
  client: DbClient,
  scope: AppliedArtifactScope,
): Promise<{ available: boolean; states: Map<string, AppliedArtifactState<Kind>> }> {
  const schema = scope.schema ?? "workbench";
  try {
    const { rows } = await client.query<AppliedArtifactRow<Kind>>(
      `SELECT artifact_key, artifact_kind, artifact_name, artifact_hash, artifact_file, applied_at::text
         FROM ${quoteIdent(schema)}.${quoteIdent(scope.table)}
        WHERE ${quoteIdent(scope.scopeColumn)} = $1`,
      [scope.scopeValue],
    );

    return { available: true, states: mapAppliedArtifactRows(rows) };
  } catch (error: unknown) {
    const code = (error as { code?: string }).code;
    if (code === "42P01" || code === "3F000") {
      return { available: false, states: new Map() };
    }
    throw error;
  }
}

export async function upsertAppliedArtifactState<Kind extends string = string>(
  client: DbClient,
  scope: AppliedArtifactScope,
  artifact: ArtifactLike<Kind>,
  file?: string,
): Promise<void> {
  const schema = scope.schema ?? "workbench";
  await client.query(
    `INSERT INTO ${quoteIdent(schema)}.${quoteIdent(scope.table)}
       (${quoteIdent(scope.scopeColumn)}, artifact_key, artifact_kind, artifact_name, artifact_file, artifact_hash, applied_at)
     VALUES ($1, $2, $3, $4, $5, $6, now())
     ON CONFLICT (${quoteIdent(scope.scopeColumn)}, artifact_key)
     DO UPDATE SET
       artifact_kind = EXCLUDED.artifact_kind,
       artifact_name = EXCLUDED.artifact_name,
       artifact_file = EXCLUDED.artifact_file,
       artifact_hash = EXCLUDED.artifact_hash,
       applied_at = now()`,
    [scope.scopeValue, artifact.key, artifact.kind, artifact.name, file ?? null, artifact.hash],
  );
}

function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}
