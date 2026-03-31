// Direct test of the entity expander — bypasses parser (Phase F not yet done)
import { expandEntities } from "../../dist/core/plx/entity-expander.js";
import { generate } from "../../dist/core/plx/codegen.js";

/** @type {import("../../dist/core/plx/ast.js").PlxModule} */
const mod = {
  imports: [],
  traits: [],
  entities: [
    {
      kind: "entity",
      schema: "expense",
      name: "category",
      table: "expense.category",
      uri: "expense://category",
      icon: "🏷",
      label: "expense.entity_category",
      traits: ["auditable"],
      fields: [
        { name: "name", type: "text", nullable: false, required: true, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "accounting_code", type: "text", nullable: true, required: false, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
      ],
      view: {
        compact: ["name", "accounting_code"],
        standard: { fields: ["name", "accounting_code"] },
        expanded: { fields: ["name", "accounting_code", "created_at"] },
        form: [
          {
            label: "expense.section_info",
            fields: [
              { key: "name", type: "text", label: "expense.field_name", required: true },
              { key: "accounting_code", type: "text", label: "expense.field_accounting_code" },
            ],
          },
        ],
      },
      actions: [
        { name: "edit", label: "expense.action_edit", icon: "✏", variant: "muted" },
        { name: "delete", label: "expense.action_delete", icon: "×", variant: "danger", confirm: "expense.confirm_delete_category" },
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

console.log(`Generated ${result.functions.length} functions + ${result.ddlFragments.length} DDL fragments\n`);

// Print DDL
console.log("=== DDL ===");
console.log(result.ddlFragments.join("\n"));
console.log();

// Print each generated function
for (const fn of result.functions) {
  console.log(`=== ${fn.schema}.${fn.name} ===`);
  try {
    console.log(generate(fn));
  } catch (e) {
    console.error(`  CODEGEN ERROR: ${e.message}`);
  }
  console.log();
}
