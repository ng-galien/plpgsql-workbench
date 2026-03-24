import { pgv } from "./supabase";

export async function crud(verb: string, uri: string, data?: Record<string, unknown>) {
  const { data: result, error } = await pgv.rpc("route_crud", {
    p_verb: verb,
    p_uri: uri,
    p_data: data ?? null,
  });
  if (error) throw error;
  return result;
}

/** Shorthand for get */
export const get = (uri: string) => crud("get", uri);
