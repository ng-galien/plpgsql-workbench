import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";
import { queryFunctionDdl } from "../../core/resources/function.js";
import { PlUri } from "../../core/uri.js";
import type { SetFunctionFn } from "./func-set.js";

export function createFuncEditTool({
  withClient,
  setFunction,
}: {
  withClient: WithClient;
  setFunction: SetFunctionFn;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_func_edit",
      description:
        "Patch a PL/pgSQL function body. Fetches current DDL, applies old->new replacements, deploys and validates.\n" +
        "Only for functions/procedures. Use pg_func_set for other object types.\n" +
        "Each edit must match exactly once in the source (like a surgical patch).",
      schema: z.object({
        uri: z.string().describe("Function URI. Ex: plpgsql://public/function/transfer"),
        edits: z
          .array(
            z.object({
              old: z.string().describe("Exact text to find in the function source"),
              new: z.string().describe("Replacement text"),
            }),
          )
          .describe("List of old->new replacements, applied sequentially"),
        context_token: z
          .string()
          .optional()
          .describe("Context token from pg_get. Required for modifying existing functions."),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string;
      const edits = args.edits as { old: string; new: string }[];
      const parsed = PlUri.parse(uri);
      if (!parsed || parsed.kind !== "function" || !parsed.name) {
        return text(
          "problem: edit only works on functions\nwhere: pg_func_edit\nfix_hint: URI must be plpgsql://schema/function/name",
        );
      }

      return withClient(async (client) => {
        const ddl = await queryFunctionDdl(client, parsed.schema, parsed.name!);
        if (!ddl)
          return text(
            `problem: function ${parsed.schema}.${parsed.name} not found\nwhere: pg_func_edit\nfix_hint: check the URI`,
          );

        let patched = ddl;
        for (let i = 0; i < edits.length; i++) {
          const { old: oldStr, new: newStr } = edits[i]!;
          const count = patched.split(oldStr).length - 1;

          if (count === 0) {
            // Whitespace-tolerant fallback: normalize spaces/tabs/newlines
            const normalize = (s: string) => s.replace(/\s+/g, " ").trim();
            const normPatched = normalize(patched);
            const normOld = normalize(oldStr);
            const normCount = normPatched.split(normOld).length - 1;

            if (normCount === 1) {
              // Find the actual substring in the original using a flexible regex
              const escaped = oldStr.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+");
              const flexRegex = new RegExp(escaped);
              const match = patched.match(flexRegex);
              if (match) {
                patched = patched.replace(flexRegex, newStr);
                continue;
              }
            }

            return text(
              `✗ edit ${i + 1} failed\nproblem: old string not found (also tried whitespace-tolerant match)\nwhere: ${parsed.schema}.${parsed.name}`,
            );
          }
          if (count > 1) {
            return text(
              `✗ edit ${i + 1} failed\nproblem: old string matches ${count} times (must be unique)\nwhere: ${parsed.schema}.${parsed.name}`,
            );
          }
          patched = patched.replace(oldStr, newStr);
        }

        const contextToken = args.context_token as string | undefined;
        return await setFunction(client, parsed.schema, parsed.name!, patched, undefined, contextToken);
      });
    },
  };
}
