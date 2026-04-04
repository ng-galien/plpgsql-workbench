import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../core/resources/catalog.js", () => ({
  queryCatalog: vi.fn(async () => [{ name: "crm" }, { name: "billing" }]),
  formatCatalog: vi.fn(() => "catalog body"),
}));

vi.mock("../../../core/resources/schema.js", () => ({
  querySchema: vi.fn(async (_client, schema: string) => ({
    schema,
    tables: [{ name: "client" }],
    functions: [{ name: "client_read" }],
    triggers: [{ name: "client_trigger" }],
  })),
  formatSchema: vi.fn(() => "schema body"),
}));

vi.mock("../../../core/resources/function.js", () => ({
  queryFunction: vi.fn(async (_client, schema: string, name: string) => ({
    schema,
    name,
    tables_used: [{ name: "client", mode: "r" }],
    callers: [],
  })),
  formatFunction: vi.fn(() => "function body"),
}));

vi.mock("../../../core/resources/table.js", () => ({
  queryTable: vi.fn(async (_client, schema: string, name: string) => ({
    schema,
    name,
    used_by: [{ name: "client_read" }],
  })),
  formatTable: vi.fn(() => "table body"),
}));

vi.mock("../../../core/resources/trigger.js", () => ({
  queryTrigger: vi.fn(async () => ({ table: "client", function: "client_touch" })),
  formatTrigger: vi.fn(() => "trigger body"),
}));

vi.mock("../../../core/resources/type.js", () => ({
  queryType: vi.fn(async () => ({ name: "client_kind" })),
  formatType: vi.fn(() => "type body"),
}));

vi.mock("../../../core/workbench.js", () => ({
  resolveDoc: vi.fn(async (_client, topic: string) => `doc:${topic}`),
  resolveDocIndex: vi.fn(async () => "doc:index"),
}));

vi.mock("../../../core/context-token.js", () => ({
  computeContextToken: vi.fn(async () => "ctx-123"),
}));

afterEach(() => {
  vi.clearAllMocks();
});

describe("pg_get resolveUri", () => {
  it("uses target resolution for catalog, docs, schema and function resources", async () => {
    const { resolveUri } = await import("../get.js");
    const client = { query: vi.fn() } as never;

    await expect(resolveUri("plpgsql://", client)).resolves.toBe(
      "uri: plpgsql://\ncompleteness: full\n\ncatalog body\n\nnext:\n  - pg_get plpgsql://crm\n  - pg_get plpgsql://billing",
    );
    await expect(resolveUri("plpgsql://workbench/doc/testing", client)).resolves.toBe("doc:testing");
    await expect(resolveUri("plpgsql://crm", client)).resolves.toBe(
      "uri: plpgsql://crm\ncompleteness: full\n\nschema body\n\nnext:\n  - pg_get plpgsql://crm/function/*\n  - pg_get plpgsql://crm/table/*\n  - pg_search schema:crm name:%pattern%",
    );
    await expect(resolveUri("plpgsql://crm/function/client_read", client)).resolves.toBe(
      "uri: plpgsql://crm/function/client_read\ncompleteness: full\n\nfunction body\n  context_token: ctx-123\n\nnext:\n  - pg_get plpgsql://crm/table/client",
    );
    await expect(resolveUri("plpgsql://crm/view/index", client)).resolves.toBe(
      "✗ invalid URI: plpgsql://crm/view/index",
    );
  });
});
