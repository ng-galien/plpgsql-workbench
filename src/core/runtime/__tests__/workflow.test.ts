import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { diffRuntimeArtifacts, prepareRuntimeWorkflow, sortRuntimeArtifacts } from "../workflow.js";

const tmpRoots: string[] = [];

async function createWorkspace(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "runtime-workflow-"));
  tmpRoots.push(root);
  await fs.mkdir(path.join(root, "runtime", "sdui", "build"), { recursive: true });
  await fs.mkdir(path.join(root, "runtime", "sdui", "src"), { recursive: true });
  await fs.mkdir(path.join(root, "runtime", "sdui", "tests"), { recursive: true });
  return root;
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("runtime workflow", () => {
  it("prepares runtime artifacts from build, src and tests", async () => {
    const root = await createWorkspace();
    await fs.writeFile(
      path.join(root, "runtime", "sdui", "build", "sdui.ddl.sql"),
      "CREATE SCHEMA IF NOT EXISTS sdui;",
    );
    await fs.writeFile(
      path.join(root, "runtime", "sdui", "src", "api.sql"),
      "CREATE OR REPLACE FUNCTION sdui.api() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;",
    );
    await fs.writeFile(
      path.join(root, "runtime", "sdui", "tests", "test_api.sql"),
      "CREATE OR REPLACE FUNCTION sdui_ut.test_api() RETURNS SETOF text LANGUAGE sql AS $$ SELECT 'ok' $$;",
    );

    const workflow = await prepareRuntimeWorkflow(root, "sdui");

    expect(workflow.buildFiles).toEqual(["build/sdui.ddl.sql"]);
    expect(workflow.srcFiles).toEqual(["src/api.sql"]);
    expect(workflow.testFiles).toEqual(["tests/test_api.sql"]);
    expect(workflow.artifacts.map((artifact) => artifact.key)).toEqual([
      "ddl:build/sdui.ddl.sql",
      "ddl:schema:sdui_ut",
      "sql:src/api.sql",
      "test:tests/test_api.sql",
    ]);
  });

  it("sorts runtime artifacts by ddl, src then tests", async () => {
    const root = await createWorkspace();
    await fs.writeFile(
      path.join(root, "runtime", "sdui", "build", "sdui.ddl.sql"),
      "CREATE SCHEMA IF NOT EXISTS sdui;",
    );
    await fs.writeFile(path.join(root, "runtime", "sdui", "src", "b.sql"), "SELECT 2;");
    await fs.writeFile(path.join(root, "runtime", "sdui", "src", "a.sql"), "SELECT 1;");
    await fs.writeFile(path.join(root, "runtime", "sdui", "tests", "test_api.sql"), "SELECT 3;");

    const workflow = await prepareRuntimeWorkflow(root, "sdui");
    const ordered = sortRuntimeArtifacts(workflow.artifacts);

    expect(ordered.map((artifact) => artifact.key)).toEqual([
      "ddl:build/sdui.ddl.sql",
      "ddl:schema:sdui_ut",
      "sql:src/a.sql",
      "sql:src/b.sql",
      "test:tests/test_api.sql",
    ]);
  });

  it("diffs runtime artifacts against applied state", async () => {
    const root = await createWorkspace();
    await fs.writeFile(
      path.join(root, "runtime", "sdui", "build", "sdui.ddl.sql"),
      "CREATE SCHEMA IF NOT EXISTS sdui;",
    );
    await fs.writeFile(path.join(root, "runtime", "sdui", "src", "api.sql"), "SELECT 1;");

    const workflow = await prepareRuntimeWorkflow(root, "sdui");
    const api = workflow.artifacts.find((artifact) => artifact.key === "sql:src/api.sql");
    expect(api).toBeDefined();
    if (!api) throw new Error("missing api artifact");

    const diff = diffRuntimeArtifacts(
      workflow.artifacts,
      new Map([
        [
          "sql:src/api.sql",
          {
            key: "sql:src/api.sql",
            kind: "sql" as const,
            name: "api",
            file: "src/api.sql",
            hash: api.hash,
            appliedAt: "2026-04-04 00:00:00+00",
          },
        ],
        [
          "sql:src/old.sql",
          {
            key: "sql:src/old.sql",
            kind: "sql" as const,
            name: "old",
            file: "src/old.sql",
            hash: "deadbeef",
            appliedAt: "2026-04-03 00:00:00+00",
          },
        ],
      ]),
    );

    expect(diff.unchanged.map((artifact) => artifact.key)).toEqual(["sql:src/api.sql"]);
    expect(diff.changed.map((artifact) => artifact.key)).toEqual(["ddl:build/sdui.ddl.sql"]);
    expect(diff.obsolete.map((artifact) => artifact.key)).toEqual(["sql:src/old.sql"]);
  });
});
