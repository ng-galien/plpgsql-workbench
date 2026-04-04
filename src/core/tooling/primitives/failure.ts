export interface ToolFailure {
  problem: string;
  where: string;
  fixHint?: string;
  stage?: string;
}

export function createToolFailure(
  problem: string,
  where: string,
  options: Omit<ToolFailure, "problem" | "where"> = {},
): ToolFailure {
  return {
    problem,
    where,
    fixHint: options.fixHint,
    stage: options.stage,
  };
}

export function toolFailureFromError(
  error: unknown,
  where: string,
  options: Omit<ToolFailure, "problem" | "where"> = {},
): ToolFailure {
  const problem = error instanceof Error ? error.message : String(error);
  return createToolFailure(problem, where, options);
}

export function formatToolFailure(failure: ToolFailure): string {
  const lines = [`problem: ${failure.problem}`, `where: ${failure.where}`];
  if (failure.stage) lines.push(`failure_stage: ${failure.stage}`);
  if (failure.fixHint) lines.push(`fix_hint: ${failure.fixHint}`);
  return lines.join("\n");
}
