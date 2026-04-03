import { describe, expect, it } from "vitest";
import { type PlxEntity, pointLoc } from "../ast.js";
import { generateDDL, type ResolvedEntityFields } from "../entity-ddl.js";
import { formatDefaultValue } from "../entity-sql.js";

const LOC = pointLoc(1, 1);

describe("entity DDL generation", () => {
  it("generates table, state, foreign key and grant artifacts", () => {
    const entity: PlxEntity = {
      kind: "entity",
      visibility: "export",
      schema: "demo",
      name: "task",
      table: "demo.task",
      uri: "demo://task",
      label: "demo.task",
      traits: [],
      storage: "hybrid",
      columns: [
        {
          name: "rank",
          type: "int",
          nullable: true,
          defaultValue: "0",
          required: false,
          unique: false,
          createOnly: false,
          readOnly: false,
          loc: LOC,
        },
        {
          name: "owner_id",
          type: "int",
          nullable: true,
          required: false,
          unique: false,
          createOnly: false,
          readOnly: false,
          ref: "demo.user",
          loc: LOC,
        },
      ],
      payload: [
        {
          name: "title",
          type: "text",
          nullable: false,
          required: true,
          unique: false,
          createOnly: false,
          readOnly: false,
          loc: LOC,
        },
      ],
      fields: [],
      states: {
        column: "phase",
        initial: "draft",
        values: ["draft", "active"],
        transitions: [],
        loc: LOC,
      },
      view: { compact: ["title"] },
      events: [],
      actions: [],
      strategies: [],
      hooks: [],
      changeHandlers: [],
      listOrder: "id",
      loc: LOC,
    };

    const resolved: ResolvedEntityFields = {
      columns: entity.columns,
      payload: entity.payload,
      all: [...entity.columns, ...entity.payload],
    };

    const sql = generateDDL(entity, resolved)
      .artifacts.map((artifact) => artifact.sql)
      .join("\n\n");

    expect(sql).toContain("CREATE TABLE IF NOT EXISTS demo.task");
    expect(sql).toContain("tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id')");
    expect(sql).toContain("rank int DEFAULT 0");
    expect(sql).toContain("phase text NOT NULL DEFAULT 'draft' CHECK (phase IN ('draft', 'active'))");
    expect(sql).toContain("payload jsonb NOT NULL DEFAULT '{}'::jsonb");
    expect(sql).toContain(
      "ALTER TABLE demo.task ADD CONSTRAINT task_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES demo.user(id);",
    );
    expect(sql).toContain("GRANT USAGE ON SCHEMA demo TO anon;");
    expect(sql).toContain("CREATE INDEX IF NOT EXISTS idx_task_tenant ON demo.task(tenant_id)");
    expect(sql).toContain("ALTER TABLE demo.task ENABLE ROW LEVEL SECURITY");
    expect(sql).toContain("CREATE POLICY tenant_isolation ON demo.task");
    expect(sql).toContain("USING (tenant_id = current_setting('app.tenant_id'))");
    expect(sql).toContain("WITH CHECK (tenant_id = current_setting('app.tenant_id'))");
  });

  it("formats SQL default values according to column type", () => {
    expect(formatDefaultValue("0", "int")).toBe("0");
    expect(formatDefaultValue("now()", "timestamptz")).toBe("now()");
    expect(formatDefaultValue("O'Reilly", "text")).toBe("'O''Reilly'");
  });
});
