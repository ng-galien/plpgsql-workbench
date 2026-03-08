import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { PlUri } from "../uri.js";
import { text, withClient } from "../helpers.js";
import { runCoverage, formatCoverageReport } from "../instrument/coverage.js";
import { runTests } from "./test.js";

export function registerCoverage(s: McpServer): void {
  s.tool(
    "coverage",
    "Run code coverage analysis on a PL/pgSQL function.\n" +
      "Instruments the function, runs its unit tests, then restores the original.\n" +
      "Reports block coverage (which statements executed) and branch coverage (IF/ELSIF/ELSE/CASE/LOOP/EXCEPTION paths).",
    {
      target: z.string().describe("Function URI. Ex: plpgsql://public/function/transfer"),
    },
    async ({ target }) => {
      const parsed = PlUri.parse(target);
      if (!parsed || parsed.kind !== "function" || !parsed.name) {
        return text("✗ target must be a function URI: plpgsql://schema/function/name");
      }

      return withClient(async (client) => {
        const utSchema = `${parsed.schema}_ut`;
        const testPattern = `^test_${parsed.name}$`;

        const result = await runCoverage(
          client,
          parsed.schema,
          parsed.name!,
          async (c) => {
            await runTests(c, utSchema, testPattern);
          },
        );

        if (!result) {
          return text(`✗ function ${parsed.schema}.${parsed.name} not found`);
        }

        if (result.totalPoints === 0) {
          return text(`${parsed.schema}.${parsed.name}: no coverage points (empty function?)`);
        }

        return text(formatCoverageReport(result));
      });
    },
  );
}
