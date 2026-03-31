// Test entity expander Phase D — traits (auditable + soft_delete)
import { expandEntities } from "../../dist/core/plx/entity-expander.js";
import { generate } from "../../dist/core/plx/codegen.js";

/** @type {import("../../dist/core/plx/ast.js").PlxModule} */
const mod = {
  imports: [],
  traits: [],
  entities: [
    {
      kind: "entity",
      schema: "crm",
      name: "client",
      table: "crm.client",
      uri: "crm://client",
      label: "crm.entity_client",
      traits: ["auditable", "soft_delete"],
      fields: [
        { name: "name", type: "text", nullable: false, required: true, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "email", type: "text", nullable: false, required: true, unique: true, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "phone", type: "text", nullable: true, required: false, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
      ],
      view: {
        compact: ["name", "email"],
        form: [
          {
            label: "crm.section_identity",
            fields: [
              { key: "name", type: "text", label: "crm.field_name", required: true },
              { key: "email", type: "text", label: "crm.field_email", required: true },
              { key: "phone", type: "text", label: "crm.field_phone" },
            ],
          },
        ],
      },
      actions: [
        { name: "edit", label: "crm.action_edit", variant: "muted" },
        { name: "delete", label: "crm.action_delete", variant: "danger", confirm: "crm.confirm_delete" },
      ],
      strategies: [],
      hooks: [],
      listOrder: "name",
      loc: { line: 1, col: 0 },
    },
  ],
  functions: [],
};

const result = expandEntities(mod);

if (result.errors.length > 0) {
  console.error("ERRORS:", result.errors);
  process.exit(1);
}

console.log(`Generated ${result.functions.length} functions\n`);

// Show DDL
console.log("=== DDL ===");
console.log(result.ddlFragments[0]);
console.log();

// Show key functions
for (const fn of result.functions) {
  const sql = generate(fn);
  // Show list (scope), read (scope), delete (soft)
  if (fn.name.includes("list") || fn.name.includes("read") || fn.name.includes("delete")) {
    console.log(`=== ${fn.schema}.${fn.name} ===`);
    console.log(sql);
    console.log();
  }
}
