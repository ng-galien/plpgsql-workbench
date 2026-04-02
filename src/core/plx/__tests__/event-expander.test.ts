import { describe, expect, it } from "vitest";
import type { Expression, Loc, PlxEntity, PlxModule, Statement } from "../ast.js";
import { pointLoc } from "../ast.js";
import { buildModuleContract } from "../contract.js";
import { expandEvents } from "../event-expander.js";
import { tokenize } from "../lexer.js";
import { parse } from "../parser.js";

const LOC: Loc = pointLoc(1, 1);

describe("PLX event expander", () => {
  it("emits one bus per schema and derives local subscription types", () => {
    const entityA = makeEntity("demo", "order", {
      events: [eventDecl("submitted", [param("order_id", "int")])],
      changeHandlers: [changeHandler("update", [emitStmt("submitted", [field("new", "id")])])],
    });
    const entityB = makeEntity("demo", "invoice", {
      events: [eventDecl("posted", [param("invoice_id", "int")])],
      changeHandlers: [changeHandler("delete", [emitStmt("posted", [field("old", "id")])])],
    });

    const mod: PlxModule = {
      name: "demo",
      moduleLoc: LOC,
      depends: [],
      exports: [],
      includes: [],
      imports: [],
      traits: [],
      entities: [entityA, entityB],
      functions: [],
      subscriptions: [
        {
          kind: "subscription",
          sourceSchema: "demo",
          sourceEntity: "order",
          event: "submitted",
          params: ["order_id"],
          body: [],
          loc: LOC,
        },
      ],
      tests: [],
    };

    const result = expandEvents(mod);

    expect(result.errors).toEqual([]);
    expect(result.ddlArtifacts.filter((artifact) => artifact.key === "ddl:event-outbox:demo")).toHaveLength(1);

    const subscriptionHandler = result.functions.find((fn) => fn.name === "on_demo_order_submitted_1");
    expect(subscriptionHandler?.params).toEqual([expect.objectContaining({ name: "order_id", type: "int" })]);

    const deleteHandler = result.functions.find((fn) => fn.name === "invoice_on_delete");
    expect(JSON.stringify(deleteHandler?.body)).toContain('"object":"p_old"');

    const triggerSql = result.ddlArtifacts.find(
      (artifact) => artifact.key === "ddl:event-trigger-fn:demo.invoice",
    )?.sql;
    expect(triggerSql).toContain("IF TG_OP = 'INSERT' THEN\n    NULL;");
    expect(triggerSql).toContain("ELSIF TG_OP = 'DELETE' THEN\n    PERFORM demo.invoice_on_delete(OLD);");
  });

  it("uses dependency contracts for subscription payload typing and reports arity mismatches", () => {
    const producer = parse(
      tokenize(`
module purchase

export entity purchase.receipt:
  fields:
    status text

  event received(receipt_id int, payload jsonb)
`),
    );
    const contracts = new Map([["purchase", buildModuleContract(producer)]]);

    const consumer: PlxModule = {
      name: "stock",
      moduleLoc: LOC,
      depends: [],
      exports: [],
      includes: [],
      imports: [],
      traits: [],
      entities: [],
      functions: [],
      subscriptions: [
        {
          kind: "subscription",
          sourceSchema: "purchase",
          sourceEntity: "receipt",
          event: "received",
          params: ["receipt_id", "payload"],
          body: [],
          loc: LOC,
        },
      ],
      tests: [],
    };

    const typed = expandEvents(consumer, { dependencyContracts: contracts });
    expect(typed.errors).toEqual([]);
    const handler = typed.functions.find((fn) => fn.name === "on_purchase_receipt_received_1");
    expect(handler?.params).toEqual([
      expect.objectContaining({ name: "receipt_id", type: "int" }),
      expect.objectContaining({ name: "payload", type: "jsonb" }),
    ]);
    const registrationSql = typed.ddlArtifacts[0]?.sql ?? "";
    expect(registrationSql).toContain("($1->>''receipt_id'')::int");
    expect(registrationSql).toContain("($1->''payload'')");

    const mismatch = expandEvents(
      {
        ...consumer,
        subscriptions:
          consumer.subscriptions.length > 0 ? [{ ...consumer.subscriptions[0], params: ["receipt_id"] }] : [],
      },
      { dependencyContracts: contracts },
    );
    expect(mismatch.errors).toEqual([
      expect.objectContaining({
        message: "subscription purchase.receipt.received expects 2 parameter(s)",
      }),
    ]);
  });

  it("transforms lifecycle handlers recursively and reports unknown emits", () => {
    const entity = makeEntity("demo", "task", {
      events: [eventDecl("received", [param("payload", "jsonb")])],
      changeHandlers: [
        changeHandler("update", [
          assignStmt("current", ident("new")),
          appendStmt("items", arrayExpr([field("old", "id")])),
          assertStmt(unaryExpr("NOT", groupExpr(binaryExpr("=", field("new", "status"), literal("draft"))))),
          ifStmt(
            callExpr("coalesce", [ident("new"), ident("old")]),
            [
              assignStmt("payload", jsonExpr([{ key: "msg", value: interpExpr(["id=", field("new", "id")]) }])),
              emitStmt("received", [jsonExpr([{ key: "id", value: field("new", "id") }])]),
            ],
            [
              {
                condition: caseExpr(ident("old"), [{ pattern: literal("draft"), result: ident("new") }], ident("old")),
                body: [{ kind: "sql_statement", sql: "select 1", loc: LOC }],
              },
            ],
            [
              {
                kind: "for_in",
                variable: "row",
                query: "select 1",
                body: [assignStmt("tmp", callExpr("coalesce", [ident("new"), ident("old")]))],
                loc: LOC,
              },
            ],
          ),
          {
            kind: "match",
            subject: ident("new"),
            arms: [{ pattern: literal("ok"), body: [{ kind: "raise", message: "demo.err", loc: LOC }] }],
            elseBody: [{ kind: "return", value: sqlExpr("select 1"), isYield: false, mode: "value", loc: LOC }],
            loc: LOC,
          },
        ]),
        changeHandler("insert", [emitStmt("missing", [])]),
      ],
    });

    const result = expandEvents({
      name: "demo",
      moduleLoc: LOC,
      depends: [],
      exports: [],
      includes: [],
      imports: [],
      traits: [],
      entities: [entity],
      functions: [],
      subscriptions: [],
      tests: [],
    });

    expect(result.errors).toEqual([
      expect.objectContaining({
        entityName: "demo.task",
        message: "unknown entity event 'missing'",
      }),
    ]);

    const updateHandler = result.functions.find((fn) => fn.name === "task_on_update");
    const serialized = JSON.stringify(updateHandler?.body);
    expect(serialized).not.toContain('"kind":"emit"');
    expect(serialized).toContain('"name":"p_new"');
    expect(serialized).toContain('"name":"p_old"');
    expect(serialized).toContain('"object":"p_new"');
    expect(serialized).toContain('"object":"p_old"');
    expect(serialized).toContain('"name":"demo._emit_event"');
    expect(serialized).toContain('"kind":"case_expr"');
    expect(serialized).toContain('"kind":"string_interp"');
    expect(serialized).toContain('"kind":"sql_block"');
  });
});

function makeEntity(schema: string, name: string, overrides: Partial<PlxEntity> = {}): PlxEntity {
  return {
    kind: "entity",
    visibility: "internal",
    schema,
    name,
    table: `${schema}.${name}`,
    uri: `${schema}://${name}`,
    label: `${schema}.entity_${name}`,
    traits: [],
    storage: "row",
    columns: [],
    payload: [],
    fields: [],
    view: { compact: [] },
    events: [],
    actions: [],
    strategies: [],
    hooks: [],
    changeHandlers: [],
    listOrder: "id",
    loc: LOC,
    ...overrides,
  };
}

function param(name: string, type: string) {
  return { name, type, nullable: false, loc: LOC };
}

function eventDecl(name: string, params: ReturnType<typeof param>[]) {
  return { name, params, visibility: "internal" as const, loc: LOC };
}

function changeHandler(operation: "insert" | "update" | "delete", body: Statement[]) {
  return {
    operation,
    params: operation === "update" ? ["new", "old"] : operation === "insert" ? ["new"] : ["old"],
    body,
    loc: LOC,
  };
}

function emitStmt(eventName: string, args: Expression[]): Statement {
  return { kind: "emit", eventName, args, loc: LOC };
}

function assignStmt(target: string, value: Expression): Statement {
  return { kind: "assign", target, value, loc: LOC };
}

function appendStmt(target: string, value: Expression): Statement {
  return { kind: "append", target, value, loc: LOC };
}

function assertStmt(expression: Expression): Statement {
  return { kind: "assert", expression, message: "demo.assert", loc: LOC };
}

function ifStmt(
  condition: Expression,
  body: Statement[],
  elsifs: { condition: Expression; body: Statement[] }[],
  elseBody?: Statement[],
): Statement {
  return { kind: "if", condition, body, elsifs, elseBody, loc: LOC };
}

function ident(name: string): Expression {
  return { kind: "identifier", name, loc: LOC };
}

function field(object: string, name: string): Expression {
  return { kind: "field_access", object, field: name, loc: LOC };
}

function literal(value: string): Expression {
  return { kind: "literal", value, type: "text", loc: LOC };
}

function arrayExpr(elements: Expression[]): Expression {
  return { kind: "array_literal", elements, loc: LOC };
}

function binaryExpr(op: "=" | "AND", left: Expression, right: Expression): Expression {
  return { kind: "binary", op, left, right, loc: LOC };
}

function unaryExpr(op: "NOT", expression: Expression): Expression {
  return { kind: "unary", op, expression, loc: LOC };
}

function groupExpr(expression: Expression): Expression {
  return { kind: "group", expression, loc: LOC };
}

function callExpr(name: string, args: Expression[]): Expression {
  return { kind: "call", name, args, loc: LOC };
}

function caseExpr(
  subject: Expression,
  arms: { pattern: Expression; result: Expression }[],
  elseResult?: Expression,
): Expression {
  return { kind: "case_expr", subject, arms, elseResult, loc: LOC };
}

function jsonExpr(entries: { key: string; value: Expression }[]): Expression {
  return { kind: "json_literal", entries, loc: LOC };
}

function interpExpr(parts: (string | Expression)[]): Expression {
  return { kind: "string_interp", parts, loc: LOC };
}

function sqlExpr(sql: string): Expression {
  return { kind: "sql_block", sql, loc: LOC };
}
