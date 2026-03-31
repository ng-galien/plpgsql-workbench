// Test entity expander Phase C — state machine
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
      name: "expense_report",
      table: "expense.expense_report",
      uri: "expense://expense_report",
      icon: "📋",
      label: "expense.entity_expense_report",
      traits: ["auditable"],
      fields: [
        { name: "reference", type: "text", nullable: false, required: true, unique: true, createOnly: true, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "author", type: "text", nullable: false, required: true, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "start_date", type: "date", nullable: false, required: true, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "end_date", type: "date", nullable: false, required: true, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "comment", type: "text", nullable: true, required: false, unique: false, createOnly: false, readOnly: false, loc: { line: 0, col: 0 } },
        { name: "status", type: "text", nullable: false, required: false, unique: false, createOnly: false, readOnly: false, defaultValue: "'draft'", loc: { line: 0, col: 0 } },
      ],
      states: {
        column: "status",
        initial: "draft",
        values: ["draft", "submitted", "validated", "reimbursed", "rejected"],
        transitions: [
          { name: "submit", from: "draft", to: "submitted", loc: { line: 0, col: 0 } },
          { name: "validate", from: "submitted", to: "validated", loc: { line: 0, col: 0 } },
          { name: "reject", from: "submitted", to: "rejected", loc: { line: 0, col: 0 } },
          { name: "reimburse", from: "validated", to: "reimbursed", loc: { line: 0, col: 0 } },
        ],
        loc: { line: 0, col: 0 },
      },
      updateStates: ["draft"],
      view: {
        compact: ["reference", "author", "status"],
        form: [
          {
            label: "expense.section_info",
            fields: [
              { key: "author", type: "text", label: "expense.field_author", required: true },
              { key: "start_date", type: "date", label: "expense.field_start_date", required: true },
            ],
          },
        ],
      },
      actions: [
        { name: "edit", label: "expense.action_edit", icon: "✏", variant: "muted" },
        { name: "delete", label: "expense.action_delete", icon: "×", variant: "danger", confirm: "expense.confirm_delete" },
      ],
      strategies: [],
      hooks: [],
      listOrder: "updated_at desc",
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

for (const fn of result.functions) {
  console.log(`=== ${fn.schema}.${fn.name} ===`);
  try {
    console.log(generate(fn));
  } catch (e) {
    console.error(`  CODEGEN ERROR: ${e.message}`);
  }
  console.log();
}
