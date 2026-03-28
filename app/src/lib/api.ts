import { log } from "./log";
import { pgv } from "./supabase";

export class ProblemError extends Error {
  status: number;
  detail: string;
  instance?: string;

  constructor(problem: { title: string; status: number; detail: string; instance?: string }) {
    super(problem.title);
    this.status = problem.status;
    this.detail = problem.detail;
    this.instance = problem.instance;
  }
}

export async function crud(verb: string, uri: string, data?: Record<string, unknown>) {
  const { data: result, error } = await pgv.rpc("api", {
    p_verb: verb,
    p_uri: uri,
    p_data: data ?? null,
  });
  if (error) throw error;
  if (result && typeof result === "object" && "status" in result && "type" in result) {
    log("api", "problem", result);
    throw new ProblemError(result as { title: string; status: number; detail: string; instance?: string });
  }
  return result;
}

/** Shorthand for get */
export const get = (uri: string) => crud("get", uri);
