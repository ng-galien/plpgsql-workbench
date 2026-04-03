import { EventEmitter } from "node:events";
import { describe, expect, it, vi } from "vitest";
import { attachPoolErrorHandler, createWithClient } from "../plpgsql.js";

class FakePool extends EventEmitter {
  constructor(private readonly client: FakeClient) {
    super();
  }

  async connect(): Promise<FakeClient> {
    return this.client;
  }
}

class FakeClient extends EventEmitter {
  queries: Array<{ sql: string; params?: unknown[] }> = [];
  releasedWith: boolean | undefined;

  async query(sql: string, params?: unknown[]): Promise<{ rows: never[]; rowCount: number }> {
    this.queries.push({ sql, params });
    return { rows: [], rowCount: 0 };
  }

  release(destroy?: boolean): void {
    this.releasedWith = destroy;
  }
}

describe("plpgsqlPack connection guards", () => {
  it("logs unexpected idle pool errors instead of crashing", () => {
    const pool = new FakePool(new FakeClient());
    const logger = { error: vi.fn() };

    attachPoolErrorHandler(pool as never, logger);
    pool.emit("error", new Error("idle disconnect"));

    expect(logger.error).toHaveBeenCalledWith("[plpgsql] Unexpected idle PostgreSQL client error", expect.any(Error));
  });

  it("handles checked-out client errors and destroys broken clients on release", async () => {
    const client = new FakeClient();
    const pool = new FakePool(client);
    const logger = { error: vi.fn() };
    const withClient = createWithClient(pool as never, logger, "tenant-test");

    const result = await withClient(async (db) => {
      client.emit("error", new Error("connection terminated"));
      await db.query("SELECT 1");
      return "ok";
    });

    expect(result).toBe("ok");
    expect(logger.error).toHaveBeenCalledWith(
      "[plpgsql] PostgreSQL client error during tool execution",
      expect.any(Error),
    );
    expect(client.queries).toEqual([
      { sql: "SELECT set_config('app.tenant_id', $1, false)", params: ["tenant-test"] },
      { sql: "SELECT 1", params: undefined },
      { sql: "ROLLBACK", params: undefined },
    ]);
    expect(client.releasedWith).toBe(true);
  });
});
