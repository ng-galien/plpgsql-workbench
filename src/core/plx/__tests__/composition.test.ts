import { describe, expect, it } from "vitest";
import { compose, composeModules } from "../composition.js";
import { tokenize } from "../lexer.js";
import { parse } from "../parser.js";

describe("PLX composition", () => {
  it("accepts exported cross-module calls with declared dependencies", async () => {
    const result = await compose(
      [
        {
          file: "crm.plx",
          source: `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id, label: "client"}
`,
        },
        {
          file: "quote.plx",
          source: `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  client := crm.client_read(id)
  return client
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual([]);
  });

  it("errors when a cross-module call skips depends", async () => {
    const result = await compose(
      [
        {
          file: "crm.plx",
          source: `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
        },
        {
          file: "quote.plx",
          source: `
module quote

export fn quote.estimate_read(id int) -> jsonb:
  return crm.client_read(id)
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "module.missing-dependency",
        }),
      ]),
    );
  });

  it("errors on access to internal symbols", async () => {
    const result = await compose(
      [
        {
          file: "crm.plx",
          source: `
module crm

internal fn crm.client_read(id int) -> jsonb:
  return {id}
`,
        },
        {
          file: "quote.plx",
          source: `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return crm.client_read(id)
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "module.private-symbol-access",
        }),
      ]),
    );
  });

  it("errors on unknown exports and duplicate modules", async () => {
    const result = await compose(
      [
        {
          file: "crm-a.plx",
          source: `
module crm

export fn crm.client_list() -> jsonb:
  return []
`,
        },
        {
          file: "crm-b.plx",
          source: `
module crm

export fn crm.other() -> jsonb:
  return []
`,
        },
        {
          file: "quote.plx",
          source: `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return crm.client_read(id)
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "module.duplicate-module" }),
        expect.objectContaining({ code: "module.unknown-export" }),
      ]),
    );
  });

  it("errors on dependency cycles", async () => {
    const result = await compose(
      [
        {
          file: "crm.plx",
          source: `
module crm
depends quote

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
        },
        {
          file: "quote.plx",
          source: `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return {id}
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual(
      expect.arrayContaining([expect.objectContaining({ code: "module.dependency-cycle" })]),
    );
  });

  it("resolves imported aliases to composed modules", async () => {
    const result = await compose(
      [
        {
          file: "crm.plx",
          source: `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
        },
        {
          file: "quote.plx",
          source: `
module quote
depends crm
import crm.client_read as read_client

export fn quote.estimate_read(id int) -> jsonb:
  return read_client(id)
`,
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual([]);
  });

  it("returns parse diagnostics instead of throwing on invalid input", async () => {
    await expect(
      compose(
        [
          {
            file: "bad.plx",
            source: `fn demo.bad( -> int:`,
          },
        ],
        { validate: false },
      ),
    ).resolves.toMatchObject({
      errors: [expect.objectContaining({ code: "parse.unexpected-token", file: "bad.plx" })],
      modules: [
        expect.objectContaining({
          file: "bad.plx",
          moduleName: null,
          functionCount: 0,
          errors: [expect.objectContaining({ code: "parse.unexpected-token" })],
        }),
      ],
    });
  });

  it("returns lex diagnostics instead of throwing on invalid input", async () => {
    await expect(
      compose(
        [
          {
            file: "bad-lex.plx",
            source: `fn demo.bad() -> int:
  return $`,
          },
        ],
        { validate: false },
      ),
    ).resolves.toMatchObject({
      errors: [expect.objectContaining({ code: "lex.unexpected-character", file: "bad-lex.plx" })],
      modules: [
        expect.objectContaining({
          file: "bad-lex.plx",
          moduleName: null,
          functionCount: 0,
          errors: [expect.objectContaining({ code: "lex.unexpected-character" })],
        }),
      ],
    });
  });

  it("reports missing module declarations in composeModules", async () => {
    const result = await composeModules(
      [
        {
          file: "quote.plx",
          module: parse(
            tokenize(
              `
export fn quote.estimate_read(id int) -> jsonb:
  return {id}
`,
            ),
          ),
        },
      ],
      { validate: false },
    );

    expect(result.errors).toEqual(
      expect.arrayContaining([expect.objectContaining({ code: "module.missing-declaration" })]),
    );
  });
});
