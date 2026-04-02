import type { Loc, Param, PlxModule, Visibility } from "./ast.js";
import { pointLoc } from "./ast.js";
import type { CompileError } from "./compiler.js";
import { createDiagnostic } from "./compiler.js";
import { buildModuleFromSource, loadPlxModule } from "./module-loader.js";

export interface ModuleContractSymbol {
  kind: "entity" | "event" | "function";
  name: string;
  params?: Param[];
  returnType?: string;
  schema: string;
  setof?: boolean;
  visibility: Visibility;
}

export interface ModuleContract {
  depends: string[];
  exports: ModuleContractSymbol[];
  internals: ModuleContractSymbol[];
  moduleName: string | null;
  spans: {
    module?: Loc;
  };
}

export interface ModuleContractResult {
  contract?: ModuleContract;
  errors: CompileError[];
}

export function readModuleContract(source: string): ModuleContractResult {
  const loaded = buildModuleFromSource(source);
  if (!loaded.module) return { errors: loaded.errors };
  return { contract: buildModuleContract(loaded.module), errors: [] };
}

export async function readModuleContractEntry(entryPath: string): Promise<ModuleContractResult> {
  const loaded = await loadPlxModule(entryPath);
  if (!loaded.module) return { errors: loaded.errors };
  return { contract: buildModuleContract(loaded.module), errors: [] };
}

export function buildModuleContract(mod: PlxModule): ModuleContract {
  const symbols: ModuleContractSymbol[] = [
    ...mod.functions.map((fn) => ({
      kind: "function" as const,
      name: fn.name,
      params: fn.params,
      returnType: fn.returnType,
      schema: fn.schema,
      setof: fn.setof,
      visibility: fn.visibility,
    })),
    ...mod.entities.map((entity) => ({
      kind: "entity" as const,
      name: entity.name,
      schema: entity.schema,
      visibility: entity.visibility,
    })),
    ...mod.entities.flatMap((entity) =>
      entity.events.map((event) => ({
        kind: "event" as const,
        name: `${entity.name}.${event.name}`,
        params: event.params,
        schema: entity.schema,
        visibility: event.visibility,
      })),
    ),
  ];

  return {
    depends: mod.depends.map((dep) => dep.name),
    exports: symbols.filter((symbol) => symbol.visibility === "export"),
    internals: symbols.filter((symbol) => symbol.visibility === "internal"),
    moduleName: mod.name ?? null,
    spans: {
      module: mod.moduleLoc,
    },
  };
}

export function toContractError(
  phase: CompileError["phase"],
  error: unknown,
  fallbackCode: string,
  fallbackLoc: Loc = pointLoc(),
): CompileError {
  if (error instanceof Error && "loc" in error && typeof error.loc === "object" && error.loc) {
    return createDiagnostic(phase, (error as { code?: string }).code ?? fallbackCode, error.message, error.loc as Loc);
  }

  if (error instanceof Error && "line" in error && "col" in error) {
    return createDiagnostic(
      phase,
      (error as { code?: string }).code ?? fallbackCode,
      error.message,
      {
        file: (error as { file?: string }).file,
        line: Number((error as { line: number }).line),
        col: Number((error as { col: number }).col),
        endLine: Number((error as { endLine?: number }).endLine ?? (error as { line: number }).line),
        endCol: Number((error as { endCol?: number }).endCol ?? (error as { col: number }).col),
      },
      (error as { hint?: string }).hint,
    );
  }

  if (error instanceof Error) {
    return createDiagnostic(phase, fallbackCode, error.message, fallbackLoc);
  }

  return createDiagnostic(phase, fallbackCode, String(error), fallbackLoc);
}
