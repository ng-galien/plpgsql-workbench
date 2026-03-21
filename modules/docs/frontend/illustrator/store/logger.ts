// ============================================================
// STORE LOGGER — circular event log for audit & debugging
// ============================================================

import type { AppPhase } from "./types.js";

export interface LogEntry {
  ts: number;
  type: string;
  phase: AppPhase;
  blocked: boolean;
  detail?: string;
}

const MAX = 200;
const log: LogEntry[] = [];

export function pushLog(entry: LogEntry): void {
  log.push(entry);
  if (log.length > MAX) log.shift();
}

export function getEventLog(): LogEntry[] {
  return log;
}
