import { asFunction } from "awilix";
import { createAlterTool } from "../commands/plpgsql/alter.js";
import { createCoverageTool } from "../commands/plpgsql/coverage.js";
import { createFuncBulkDelTool } from "../commands/plpgsql/func-bulk-del.js";
import { createFuncDelTool } from "../commands/plpgsql/func-del.js";
import { createFuncEditTool } from "../commands/plpgsql/func-edit.js";
import { createFuncLoadTool } from "../commands/plpgsql/func-load.js";
import { createFuncRenameTool } from "../commands/plpgsql/func-rename.js";
import { createFuncSaveTool } from "../commands/plpgsql/func-save.js";
import { createFuncSetTool, createSetFunction } from "../commands/plpgsql/func-set.js";
import { createTestTool, formatTestReport, runTests } from "../commands/plpgsql/test.js";
import { type HookRule, inputStr, type Plugin } from "../core/plugin.js";

const INTERNAL_CALL_RE = /\b(\w+)\._(\w+)\s*\(/g;

function denyForeignSchema(
  ctx: import("../core/plugin.js").HookContext,
  tool: string,
  schema: string,
): import("../core/plugin.js").HookDecision | null {
  if (schema && !ctx.schemas.includes(schema)) {
    return {
      action: "deny",
      reason: `Module ${ctx.module}: ${tool} interdit sur le schema '${schema}'. Schemas autorises: ${ctx.schemas.join(", ")}`,
    };
  }
  return null;
}

export const pgFunctionsPlugin: Plugin = {
  id: "pg-functions",
  name: "Function Lifecycle & Testing",
  requires: ["withClient"],

  register(container) {
    container.register({
      setFunction: asFunction(createSetFunction).singleton(),
      runTests: asFunction(() => runTests).singleton(),
      formatTestReport: asFunction(() => formatTestReport).singleton(),

      funcSetTool: asFunction(createFuncSetTool).singleton(),
      funcEditTool: asFunction(createFuncEditTool).singleton(),
      funcDelTool: asFunction(createFuncDelTool).singleton(),
      funcRenameTool: asFunction(createFuncRenameTool).singleton(),
      funcBulkDelTool: asFunction(createFuncBulkDelTool).singleton(),
      funcSaveTool: asFunction(createFuncSaveTool).singleton(),
      funcLoadTool: asFunction(createFuncLoadTool).singleton(),
      alterTool: asFunction(createAlterTool).singleton(),
      testTool: asFunction(createTestTool).singleton(),
      coverageTool: asFunction(createCoverageTool).singleton(),
    });
  },

  hooks(): HookRule[] {
    return [
      {
        toolPattern: /pg_func_set$/,
        evaluate(ctx) {
          const schema = inputStr(ctx, "schema");
          const denied = denyForeignSchema(ctx, "pg_func_set", schema);
          if (denied) return denied;
          const body = inputStr(ctx, "body");
          const internalCalls: string[] = [];
          const re = new RegExp(INTERNAL_CALL_RE.source, INTERNAL_CALL_RE.flags);
          let match = re.exec(body);
          while (match !== null) {
            const callSchema = match[1]!;
            if (!ctx.schemas.includes(callSchema)) {
              internalCalls.push(`${callSchema}._${match[2]}`);
            }
            match = re.exec(body);
          }
          if (internalCalls.length > 0) {
            return {
              action: "deny",
              reason: `Module ${ctx.module}: appel a des fonctions internes d'un autre module interdit.\nViolations: ${internalCalls.join(", ")}\n\nConvention: schema._name() = interne, cross-module interdit.`,
            };
          }
          if (schema === "pgv" && /style\s*=\s*"/.test(body)) {
            return {
              action: "deny",
              reason:
                'Les fonctions pgv ne doivent pas contenir de style inline (style="..."). Utilise class="pgv-*" et definis les styles dans pgview.css.',
            };
          }
          return null;
        },
      },
      {
        toolPattern: /pg_func_edit$/,
        evaluate(ctx) {
          return denyForeignSchema(ctx, "pg_func_edit", inputStr(ctx, "schema"));
        },
      },
      {
        toolPattern: /pg_func_del$/,
        evaluate(ctx) {
          const uri = inputStr(ctx, "uri");
          const schema = uri.match(/^plpgsql:\/\/([^/]+)/)?.[1] ?? "";
          return denyForeignSchema(ctx, "pg_func_del", schema);
        },
      },
    ];
  },
};
