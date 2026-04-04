import type { PlxModule } from "./ast.js";
import { pointLoc } from "./ast.js";
import type { CompileError } from "./compiler.js";
import { createDiagnostic } from "./compiler.js";
import type { DdlArtifact } from "./entity-ddl.js";
import { sqlEscape } from "./util.js";

interface I18nExpandResult {
  artifacts: DdlArtifact[];
  errors: CompileError[];
}

export function expandI18n(mod: PlxModule): I18nExpandResult {
  if (mod.i18n.length === 0) return { artifacts: [], errors: [] };
  if (!mod.name) {
    return {
      artifacts: [],
      errors: [
        createDiagnostic(
          "codegen",
          "codegen.i18n-missing-module",
          "i18n blocks require a module declaration",
          mod.i18n[0]?.loc ?? pointLoc(),
          "Declare `module <name>` in the entry file before defining translations.",
        ),
      ],
    };
  }

  const tuples = mod.i18n.flatMap((block) =>
    block.entries.map(
      (entry) => `    ('${sqlEscape(block.lang)}', '${sqlEscape(entry.key)}', '${sqlEscape(entry.value)}')`,
    ),
  );

  if (tuples.length === 0) return { artifacts: [], errors: [] };

  const schema = mod.name;
  const sql = `CREATE OR REPLACE FUNCTION ${schema}.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO i18n.translation (lang, key, value) VALUES
${tuples.join(",\n")}
  ON CONFLICT (lang, key) DO UPDATE SET value = EXCLUDED.value;
END;
$function$;
COMMENT ON FUNCTION ${schema}.i18n_seed() IS 'Seed i18n translations for ${schema} module.';`;

  return {
    artifacts: [
      {
        key: `ddl:i18n-seed:${schema}`,
        name: `${schema}.i18n_seed`,
        sql,
        dependsOn: [`ddl:schema:${schema}`],
      },
    ],
    errors: [],
  };
}
