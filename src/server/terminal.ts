import { execFile, execFileSync } from "node:child_process";
import fsSync from "node:fs";
import type http from "node:http";
import path from "node:path";
import { promisify } from "node:util";
import type { AwilixContainer } from "awilix";
import type { Express } from "express";
import pty from "node-pty";
import { type WebSocket, WebSocketServer } from "ws";
import { resolveWorkspaceRoot } from "../core/workspace.js";

const execFileAsync = promisify(execFile);

export interface TerminalDeps {
  container: AwilixContainer;
  log: { info: (...args: any[]) => void; error: (...args: any[]) => void };
}

// --- Constants ---
const BATCH_INTERVAL_DEFAULT = 16;
const BATCH_INTERVAL_BURST = 50;
const BATCH_FLUSH_THRESHOLD = 65536;
const WS_PING_INTERVAL = 15000;
const WS_BACKPRESSURE_LIMIT = 262144;
const TERMINAL_IDLE_TIMEOUT = 2 * 60 * 60 * 1000; // 2 hours

// --- Shared state ---
interface OutputBatch {
  chunks: string[];
  size: number;
  timer: ReturnType<typeof setTimeout> | null;
  lastEvent: number;
}
const outputBatches = new Map<string, OutputBatch>();
const terminals = new Map<
  string,
  { proc: pty.IPty; clients: Set<WebSocket>; sessionId: number | null; idleTimer: ReturnType<typeof setTimeout> | null }
>();

function resetIdleTimer(mod: string, deps: TerminalDeps) {
  const term = terminals.get(mod);
  if (!term) return;
  if (term.idleTimer) clearTimeout(term.idleTimer);
  term.idleTimer = setTimeout(() => {
    if (term.clients.size === 0) {
      deps.log.info({ mod }, "Terminal idle timeout — killing orphaned process");
      try {
        term.proc.kill();
      } catch {
        /* already dead */
      }
    }
  }, TERMINAL_IDLE_TIMEOUT);
}

// Clean env for pty
const ptyEnv: Record<string, string> = {};
for (const [k, v] of Object.entries(process.env)) {
  if (v !== undefined) ptyEnv[k] = v;
}
ptyEnv.TERM = "xterm-256color";
delete ptyEnv.TMUX;
delete ptyEnv.TMUX_PANE;

const CLAUDE_VARS_TO_STRIP = [
  "CLAUDECODE",
  "CLAUDE_CODE_ENTRYPOINT",
  "CLAUDE_CODE_SESSION_ID",
  "CLAUDE_CODE_CONVERSATION_ID",
  "CLAUDE_CODE_TASK_ID",
  "NON_INTERACTIVE",
  "MCP_TRANSPORT",
  "MCP_SESSION_ID",
];

// Resolve tmux binary
const TMUX_BIN = (() => {
  for (const p of ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]) {
    if (fsSync.existsSync(p)) return p;
  }
  try {
    return execFileSync("/bin/sh", ["-c", "command -v tmux"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch {
    return "tmux";
  }
})();

function resolveModulePath(mod: string): string {
  return path.join(resolveWorkspaceRoot(), "modules", mod);
}

// --- Batching ---
function batchBroadcast(key: string, data: string, clients: Set<WebSocket>) {
  let batch = outputBatches.get(key);
  if (!batch) {
    batch = { chunks: [], size: 0, timer: null, lastEvent: 0 };
    outputBatches.set(key, batch);
  }
  const now = Date.now();
  batch.chunks.push(data);
  batch.size += data.length;
  if (batch.size >= BATCH_FLUSH_THRESHOLD) {
    flushBatch(key, clients);
    return;
  }
  if (!batch.timer) {
    const gap = now - batch.lastEvent;
    const interval = gap < 10 ? BATCH_INTERVAL_BURST : BATCH_INTERVAL_DEFAULT;
    batch.timer = setTimeout(() => flushBatch(key, clients), interval);
  }
  batch.lastEvent = now;
}

function flushBatch(key: string, clients: Set<WebSocket>) {
  const batch = outputBatches.get(key);
  if (!batch || batch.chunks.length === 0) return;
  const combined = batch.chunks.join("");
  batch.chunks = [];
  batch.size = 0;
  if (batch.timer) {
    clearTimeout(batch.timer);
    batch.timer = null;
  }
  for (const client of clients) {
    if (client.readyState !== 1) continue;
    if (client.bufferedAmount > WS_BACKPRESSURE_LIMIT) continue;
    client.send(combined);
  }
}

function setupWsPing(ws: WebSocket) {
  let alive = true;
  ws.on("pong", () => {
    alive = true;
  });
  const interval = setInterval(() => {
    if (!alive) {
      clearInterval(interval);
      ws.terminate();
      return;
    }
    alive = false;
    ws.ping();
  }, WS_PING_INTERVAL);
  ws.on("close", () => clearInterval(interval));
}

// --- DB session tracking ---
async function createAgentSession(container: AwilixContainer, mod: string): Promise<number | null> {
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(`SELECT workbench.session_create($1, $2)`, [mod, process.pid]);
    return rows[0]?.session_create ?? null;
  } catch {
    return null;
  }
}

async function endAgentSession(container: AwilixContainer, sessionId: number | null, status: string) {
  if (!sessionId) return;
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    await pool.query(`SELECT workbench.session_end($1, $2)`, [sessionId, status]);
  } catch {
    /* silent */
  }
}

// --- tmux attach handler ---
function handleTmuxAttach(ws: WebSocket, session: string, deps: TerminalDeps) {
  try {
    execFileSync(TMUX_BIN, ["has-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
  } catch {
    ws.send(`\r\n\x1b[31mSession not found: ${session}\x1b[0m\r\n`);
    ws.close();
    return;
  }

  let proc: pty.IPty;
  let scrollbackSent = false;
  try {
    proc = pty.spawn(TMUX_BIN, ["attach-session", "-t", session], {
      name: "xterm-256color",
      cols: 80,
      rows: 24,
      env: ptyEnv,
    });
  } catch (err) {
    deps.log.error({ err, tmux: TMUX_BIN, session }, "Failed to spawn pty for tmux attach");
    ws.send(`\r\n\x1b[31mFailed to attach: ${session}\x1b[0m\r\n`);
    ws.close();
    return;
  }

  deps.log.info({ session, pid: proc.pid }, "Attached pty to tmux session");

  let paused = false;
  let drainInterval: ReturnType<typeof setInterval> | null = null;
  proc.onData((chunk: string) => {
    if (ws.readyState !== 1) return;
    if (ws.bufferedAmount >= WS_BACKPRESSURE_LIMIT) {
      if (!paused) {
        paused = true;
        proc.pause();
        drainInterval = setInterval(() => {
          if (ws.readyState !== 1) {
            clearInterval(drainInterval!);
            drainInterval = null;
            return;
          }
          if (ws.bufferedAmount < WS_BACKPRESSURE_LIMIT / 2) {
            clearInterval(drainInterval!);
            drainInterval = null;
            paused = false;
            proc.resume();
          }
        }, 50);
      }
      return;
    }
    ws.send(chunk);
  });

  proc.onExit(({ exitCode }) => {
    deps.log.info({ session, exitCode }, "tmux pty exited");
    if (ws.readyState === 1) ws.send(`\r\n\x1b[33m[tmux session ended]\x1b[0m\r\n`);
  });

  setupWsPing(ws);

  ws.on("message", (data: Buffer | string) => {
    const msg = typeof data === "string" ? data : data.toString();
    try {
      const parsed = JSON.parse(msg);
      if (parsed.type === "resize" && parsed.cols && parsed.rows) {
        proc.resize(Math.max(20, Math.floor(parsed.cols)), Math.max(5, Math.floor(parsed.rows)));
        if (!scrollbackSent) {
          scrollbackSent = true;
          try {
            const scrollback = execFileSync(TMUX_BIN, ["capture-pane", "-t", session, "-p", "-e", "-S", "-500"], {
              encoding: "utf8",
              stdio: ["ignore", "pipe", "pipe"],
            });
            if (scrollback.trim()) ws.send(scrollback);
          } catch {
            /* no scrollback */
          }
        }
        return;
      }
    } catch {
      /* not JSON */
    }
    proc.write(msg);
  });

  ws.on("close", () => {
    if (drainInterval) {
      clearInterval(drainInterval);
      drainInterval = null;
    }
    try {
      proc.kill();
    } catch {}
  });
}

// --- Mount ---
export function mountTerminal(httpServer: http.Server, app: Express, deps: TerminalDeps): void {
  const { container, log } = deps;
  const wss = new WebSocketServer({ noServer: true, perMessageDeflate: false });

  log.info({ tmux: TMUX_BIN }, "Resolved tmux binary");

  httpServer.on("upgrade", (req, socket, head) => {
    if (process.env.WORKBENCH_MODE !== "dev") {
      socket.destroy();
      return;
    }
    log.info({ url: req.url }, "WS upgrade request");

    const tmuxMatch = req.url?.match(/^\/ws\/tmux\/([a-zA-Z0-9_.-]+)$/);
    if (tmuxMatch) {
      const session = tmuxMatch[1]!;
      wss.handleUpgrade(req, socket, head, (ws) => handleTmuxAttach(ws, session, deps));
      return;
    }

    const match = req.url?.match(/^\/ws\/terminal\/([a-z0-9_-]+)$/);
    if (!match) {
      socket.destroy();
      return;
    }
    const mod = match[1];
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit("connection", ws, req, mod);
    });
  });

  wss.on("connection", async (ws: WebSocket, _req: http.IncomingMessage, mod: string) => {
    let term = terminals.get(mod);

    if (!term || term.proc.pid <= 0) {
      const placeholder = {
        proc: null as unknown as pty.IPty,
        clients: new Set<WebSocket>(),
        sessionId: null as number | null,
        idleTimer: null as ReturnType<typeof setTimeout> | null,
      };
      terminals.set(mod, placeholder);

      const modPath = resolveModulePath(mod);
      if (!fsSync.existsSync(modPath)) {
        terminals.delete(mod);
        ws.send(`\r\n\x1b[31mModule directory not found: ${modPath}\x1b[0m\r\n`);
        ws.close();
        return;
      }

      const sessionId = await createAgentSession(container, mod);
      const shell = process.env.SHELL ?? "/bin/zsh";
      let proc: pty.IPty;
      try {
        proc = pty.spawn(shell, [], { name: "xterm-256color", cols: 120, rows: 40, cwd: modPath, env: ptyEnv });
      } catch (err) {
        log.error({ err, mod }, "Failed to spawn agent terminal");
        terminals.delete(mod);
        void endAgentSession(container, sessionId, "error");
        ws.send(`\r\n\x1b[31mFailed to spawn terminal for ${mod}\x1b[0m\r\n`);
        ws.close();
        return;
      }

      placeholder.proc = proc;
      placeholder.sessionId = sessionId;
      term = placeholder;

      proc.onData((data: string) => {
        batchBroadcast(`terminal:${mod}`, data, term!.clients);
      });
      proc.onExit(({ exitCode }) => {
        log.info({ mod, exitCode }, "Agent terminal exited");
        void endAgentSession(container, term!.sessionId, exitCode === 0 ? "done" : "error");
        if (term!.idleTimer) clearTimeout(term!.idleTimer);
        const batch = outputBatches.get(`terminal:${mod}`);
        if (batch?.timer) clearTimeout(batch.timer);
        for (const client of term!.clients)
          client.send(`\r\n\x1b[33m[Terminal exited with code ${exitCode}]\x1b[0m\r\n`);
        terminals.delete(mod);
        outputBatches.delete(`terminal:${mod}`);
      });

      log.info({ mod, pid: proc.pid, cwd: modPath }, "Spawned agent terminal");
    }

    term.clients.add(ws);
    setupWsPing(ws);

    ws.on("message", (data: Buffer | string) => {
      const msg = typeof data === "string" ? data : data.toString();
      try {
        const parsed = JSON.parse(msg);
        if (parsed.type === "resize" && parsed.cols && parsed.rows) {
          term!.proc.resize(parsed.cols, parsed.rows);
          return;
        }
      } catch {
        /* not JSON */
      }
      term!.proc.write(msg.toString());
    });

    ws.on("close", () => {
      term?.clients.delete(ws);
      if (term && term.clients.size === 0) resetIdleTimer(mod, deps);
    });
  });

  // --- REST API ---
  app.get("/api/agents", async (_req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      const { rows } = await pool.query(`SELECT * FROM workbench.api_sessions()`);
      for (const row of rows) row.has_terminal = terminals.has(row.module);
      res.json(rows);
    } catch {
      res.json([]);
    }
  });

  app.get("/api/hooks", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    const mod = req.query.module as string | undefined;
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      const { rows } = await pool.query(`SELECT * FROM workbench.api_hooks($1)`, [mod ?? null]);
      res.json(rows);
    } catch {
      res.json([]);
    }
  });

  app.get("/api/messages", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    const mod = req.query.module as string | undefined;
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      const { rows } = await pool.query(`SELECT * FROM workbench.api_messages($1)`, [mod ?? null]);
      res.json(rows);
    } catch {
      res.json([]);
    }
  });

  app.get("/api/tmux", async (_req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    try {
      const rawSessions = execFileSync(
        TMUX_BIN,
        ["list-sessions", "-F", "#{session_name}\t#{session_created}\t#{session_activity}"],
        { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
      );
      const paneMap = new Map<string, { cwd: string; dead: boolean }>();
      try {
        const rawPanes = execFileSync(
          TMUX_BIN,
          ["list-panes", "-a", "-F", "#{session_name}\t#{pane_current_path}\t#{pane_dead}"],
          { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
        );
        for (const line of rawPanes.trim().split("\n").filter(Boolean)) {
          const [sess, cwd, dead] = line.split("\t") as [string, string, string];
          if (!paneMap.has(sess)) paneMap.set(sess, { cwd: cwd || "", dead: dead === "1" });
        }
      } catch {}

      const wsRoot = resolveWorkspaceRoot();
      const activityRe =
        /(?:Brewing|Cascading|Crunching|Churning|Cooking|Embellishing|Manifesting|Sautéed|Thinking|Worked|Cooked|Crunched|thinking|pg_func_set|pg_pack|pg_schema|pg_test|pg_query|pg_msg|Write|Edit|Read)/;
      const parsed = rawSessions
        .trim()
        .split("\n")
        .filter(Boolean)
        .map((line) => {
          const [name, created, activity] = line.split("\t") as [string, string, string];
          const pane = paneMap.get(name) ?? { cwd: "", dead: false };
          return {
            name,
            created: parseInt(created, 10) * 1000,
            activity: parseInt(activity, 10) * 1000,
            cwd: pane.cwd,
            dead: pane.dead,
            status: "idle",
          };
        })
        .filter((s) => s.cwd.startsWith(wsRoot) && !s.dead);

      await Promise.all(
        parsed.map(async (s) => {
          try {
            const { stdout } = await execFileAsync(TMUX_BIN, ["capture-pane", "-t", s.name, "-p"], {
              encoding: "utf8",
            });
            const lines = stdout.split("\n").filter((l) => activityRe.test(l));
            if (lines.length > 0) s.status = lines[lines.length - 1]!.trim();
          } catch {}
        }),
      );

      res.json(parsed);
    } catch {
      res.json([]);
    }
  });

  // --- Agent lifecycle ---
  app.post("/api/agents/:module/spawn", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    const mod = req.params.module;
    const session = mod;

    try {
      execFileSync(TMUX_BIN, ["has-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
      return res.json({ status: "already_running", module: mod, session, ws: `/ws/tmux/${session}` });
    } catch {}

    const modPath = resolveModulePath(mod);
    if (!fsSync.existsSync(modPath)) return res.status(404).json({ error: `Module not found: ${mod}` });

    const scriptFile = `/tmp/pgw-spawn-${session}.sh`;
    const script = ["#!/bin/sh", `unset ${CLAUDE_VARS_TO_STRIP.join(" ")}`, `exec claude`].join("\n");
    fsSync.writeFileSync(scriptFile, script, { mode: 0o700 });

    try {
      execFileSync(TMUX_BIN, ["new-session", "-d", "-s", session, "-c", modPath, scriptFile], {
        stdio: ["ignore", "pipe", "pipe"],
      });
      for (const [key, val] of [
        ["history-limit", "50000"],
        ["remain-on-exit", "on"],
        ["default-terminal", "xterm-256color"],
        ["mouse", "off"],
      ] as const) {
        execFileSync(TMUX_BIN, ["set-option", "-t", session, key, val], { stdio: ["ignore", "pipe", "pipe"] });
      }
      try {
        execFileSync(TMUX_BIN, ["set-option", "-t", session, "-a", "terminal-overrides", ",xterm-256color:Tc"], {
          stdio: ["ignore", "pipe", "pipe"],
        });
        execFileSync(TMUX_BIN, ["set-option", "-t", session, "extended-keys", "on"], {
          stdio: ["ignore", "pipe", "pipe"],
        });
        execFileSync(TMUX_BIN, ["set-window-option", "-q", "-t", session, "utf8", "on"], {
          stdio: ["ignore", "pipe", "pipe"],
        });
      } catch {
        /* older tmux */
      }
    } catch (err) {
      return res.status(500).json({ error: err instanceof Error ? err.message : String(err) });
    }

    const sessionId = await createAgentSession(container, mod);
    log.info({ mod, session, cwd: modPath }, "Spawned Claude agent in tmux");
    res.json({ status: "started", module: mod, session, sessionId, ws: `/ws/tmux/${session}` });
  });

  app.post("/api/agents/:module/kill", async (req, res) => {
    if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
    const mod = req.params.module;
    const session = mod;

    try {
      execFileSync(TMUX_BIN, ["has-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
      execFileSync(TMUX_BIN, ["kill-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
      try {
        fsSync.unlinkSync(`/tmp/pgw-spawn-${session}.sh`);
      } catch {}
      log.info({ mod, session }, "Killed Claude agent tmux session");
      return res.json({ status: "killed", module: mod, session });
    } catch {}

    const term = terminals.get(mod);
    if (!term) return res.json({ status: "not_running", module: mod });
    term.proc.kill();
    res.json({ status: "killed", module: mod });
  });
}
