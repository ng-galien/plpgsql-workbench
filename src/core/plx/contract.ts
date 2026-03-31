import type { Loc, Visibility } from "./ast.js";
import { pointLoc } from "./ast.js";
import type { CompileError } from "./compiler.js";
import { createDiagnostic } from "./compiler.js";
import { LexError, tokenize } from "./lexer.js";
import { ParseError } from "./parse-context.js";
import { parse } from "./parser.js";

export interface ModuleContractSymbol {
  kind: "entity" | "function";
  name: string;
  schema: string;
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
  let tokens: ReturnType<typeof tokenize>;
  try {
    tokens = tokenize(source);
  } catch (error: unknown) {
    return { errors: [toContractError("lex", error, "lex.invalid-token")] };
  }

  let mod: ReturnType<typeof parse>;
  try {
    mod = parse(tokens);
  } catch (error: unknown) {
    return { errors: [toContractError("parse", error, "parse.invalid-syntax")] };
  }

  const symbols: ModuleContractSymbol[] = [
    ...mod.functions.map((fn) => ({
      kind: "function" as const,
      name: fn.name,
      schema: fn.schema,
      visibility: fn.visibility,
    })),
    ...mod.entities.map((entity) => ({
      kind: "entity" as const,
      name: entity.name,
      schema: entity.schema,
      visibility: entity.visibility,
    })),
  ];

  return {
    contract: {
      depends: mod.depends.map((dep) => dep.name),
      exports: symbols.filter((symbol) => symbol.visibility === "export"),
      internals: symbols.filter((symbol) => symbol.visibility === "internal"),
      moduleName: mod.name ?? null,
      spans: {
        module: mod.moduleLoc,
      },
    },
    errors: [],
  };
}

function toContractError(
  phase: CompileError["phase"],
  error: unknown,
  fallbackCode: string,
  fallbackLoc: Loc = pointLoc(),
): CompileError {
  if (error instanceof LexError) {
    return createDiagnostic(
      phase,
      error.code ?? fallbackCode,
      error.message,
      {
        line: error.line,
        col: error.col,
        endLine: error.endLine,
        endCol: error.endCol,
      },
      error.hint,
    );
  }
  if (error instanceof ParseError) {
    return createDiagnostic(phase, error.code ?? fallbackCode, error.message, error.loc, error.hint);
  }
  if (error instanceof Error) {
    return createDiagnostic(phase, fallbackCode, error.message, fallbackLoc);
  }
  return createDiagnostic(phase, fallbackCode, String(error), fallbackLoc);
}
