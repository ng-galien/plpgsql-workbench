/** Supabase Realtime payload for postgres_changes */
export interface PgChangePayload {
  eventType: "INSERT" | "UPDATE" | "DELETE";
  new: Record<string, unknown>;
  old: Record<string, unknown>;
  schema: string;
  table: string;
  commit_timestamp: string;
}

export type PgChangeHandler = (payload: PgChangePayload) => void;

/** Module descriptor from app_nav() */
export interface AppModule {
  module: string;
  brand: string;
  schema: string;
  items: { href: string; label: string; icon?: string }[];
}
