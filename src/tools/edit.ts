import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { PlUri } from "../uri.js";
import { text, withClient } from "../helpers.js";
import { queryFunctionDdl } from "../resources/function.js";
import { setFunction } from "./set.js";

export function registerEdit(s: McpServer): void {
  s.tool(
    "edit",
    "Patch a PL/pgSQL function body. Fetches current DDL, applies old->new replacements, deploys and validates.\n" +
      "Only for functions/procedures. Use set for other object types.\n" +
      "Each edit must match exactly once in the source (like a surgical patch).",
    {
      uri: z.string().describe("Function URI. Ex: plpgsql://public/function/transfer"),
      edits: z.array(z.object({
        old: z.string().describe("Exact text to find in the function source"),
        new: z.string().describe("Replacement text"),
      })).describe("List of old->new replacements, applied sequentially"),
    },
    async ({ uri, edits }) => {
      const parsed = PlUri.parse(uri);
      if (!parsed || parsed.kind !== "function" || !parsed.name) {
        return text("✗ edit only works on functions. URI must be plpgsql://schema/function/name");
      }

      return withClient(async (client) => {
        const ddl = await queryFunctionDdl(client, parsed.schema, parsed.name!);
        if (!ddl) return text(`✗ function ${parsed.schema}.${parsed.name} not found`);

        let patched = ddl;
        for (let i = 0; i < edits.length; i++) {
          const { old: oldStr, new: newStr } = edits[i];
          const count = patched.split(oldStr).length - 1;
          if (count === 0) {
            return text(`✗ edit ${i + 1} failed\nproblem: old string not found\nwhere: ${parsed.schema}.${parsed.name}`);
          }
          if (count > 1) {
            return text(`✗ edit ${i + 1} failed\nproblem: old string matches ${count} times (must be unique)\nwhere: ${parsed.schema}.${parsed.name}`);
          }
          patched = patched.replace(oldStr, newStr);
        }

        return await setFunction(client, parsed.schema, parsed.name!, patched);
      });
    },
  );
}
