/** Platform config — injected in index.html, read by all modules */
export interface PgvConfig {
  rpcBase: string;
  restBase: string;
  supabaseUrl: string;
  supabaseKey: string;
  headers(accept?: string, schema?: string): Record<string, string>;
  rpc(path: string): string;
}

export function getConfig(): PgvConfig {
  const cfg = (window as any).__PGV_CONFIG__;
  if (!cfg) throw new Error("__PGV_CONFIG__ not set — inject it before loading pgview.js");
  return cfg;
}
