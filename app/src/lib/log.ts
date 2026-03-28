const enabled = import.meta.env.DEV || localStorage.getItem("debug") !== null;

export function log(scope: string, event: string, data?: unknown) {
  if (!enabled) return;
  console.log(`[${scope}] ${event}`, data ?? "");
}
