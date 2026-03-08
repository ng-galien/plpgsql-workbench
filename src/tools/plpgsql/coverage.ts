import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { PlUri } from "../../uri.js";
import { runCoverage, formatCoverageReport } from "../../instrument/coverage.js";
import type { TestReport } from "./test.js";

type RunTestsFn = (
  client: DbClient, testSchema: string, pattern?: string,
) => Promise<TestReport | null>;

export function createCoverageTool({ withClient, runTests }: {
  withClient: WithClient;
  runTests: RunTestsFn;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_coverage",
      description:
        "Run code coverage analysis on a PL/pgSQL function.\n" +
        "Instruments the function, runs its unit tests, then restores the original.\n" +
        "Reports block coverage (which statements executed) and branch coverage (IF/ELSIF/ELSE/CASE/LOOP/EXCEPTION paths).",
      schema: z.object({
        target: z.string().describe("Function URI. Ex: plpgsql://public/function/transfer"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.target as string;
      const parsed = PlUri.parse(target);
      if (!parsed || parsed.kind !== "function" || !parsed.name) {
        return text("problem: target must be a function URI\nwhere: pg_coverage\nfix_hint: use plpgsql://schema/function/name");
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
          return text(`problem: function ${parsed.schema}.${parsed.name} not found\nwhere: pg_coverage\nfix_hint: check the target URI`);
        }

        if (result.totalPoints === 0) {
          return text(`completeness: full\n\n${parsed.schema}.${parsed.name}: no coverage points (empty function?)`);
        }

        return text(`completeness: full\n\n${formatCoverageReport(result)}`);
      });
    },
  };
}
