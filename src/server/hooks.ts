import path from "node:path";
import type { AwilixContainer } from "awilix";
import type { Express, NextFunction, Request, Response } from "express";
import type { ModuleRegistry } from "../core/pgm/registry.js";
import type { HookRule } from "../core/plugin.js";
import { evaluateHookRules } from "../core/plugin-registry.js";

export interface HookDeps {
  container: AwilixContainer;
  hookRules: HookRule[];
  getModuleRegistry: () => ModuleRegistry | null;
  log: { warn: (...args: any[]) => void };
}

interface InboxRow {
  id: number;
  from_module: string;
  msg_type: string;
  subject: string;
  priority: string;
  body: string | null;
  payload: unknown;
  reply_to: number | null;
}

interface PendingRow {
  id: number;
  msg_type: string;
  priority: string;
  from_module: string;
  subject: string;
}

interface StopRow {
  id: number;
  from_module: string;
  msg_type: string;
  subject: string;
  priority: string;
  payload: unknown;
}

export function mountHooks(app: Express, deps: HookDeps): void {
  const { container, hookRules, getModuleRegistry, log } = deps;

  function logHook(mod: string, tool: string, action: string, allowed: boolean, reason?: string) {
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      pool
        .query(`SELECT workbench.log_hook($1,$2,$3,$4,$5)`, [mod, tool, action, allowed, reason ?? null])
        .catch(() => {});
    } catch {
      /* pool not ready */
    }
  }

  function deny(res: Response, reason: string, mod?: string, tool?: string, action?: string) {
    if (mod && tool) logHook(mod, tool, action ?? "", false, reason);
    res.json({
      hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: reason },
    });
  }

  function allow(res: Response, mod?: string, tool?: string, action?: string) {
    if (mod && tool) logHook(mod, tool, action ?? "", true);
    res.json({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow" } });
  }

  function validateModuleName(req: Request, res: Response, next: NextFunction) {
    const mod = req.params.module as string;
    if (!mod || mod.includes(",")) {
      return res.status(400).json({
        error: `Invalid module name "${mod}". Each agent must have a single unique module name — no comma-separated lists.`,
      });
    }
    next();
  }

  app.post("/hooks/:module", validateModuleName);
  app.post("/hooks/:module/session", validateModuleName);
  app.post("/hooks/:module/stop", validateModuleName);

  // --- PreToolUse ---
  app.post("/hooks/:module", async (req, res) => {
    const mod = req.params.module;
    const { tool_name, tool_input } = req.body ?? {};
    const moduleRegistry = getModuleRegistry();
    if (mod === "lead") return allow(res, mod, tool_name);
    if (!moduleRegistry) return allow(res, mod, tool_name, "startup");

    // Active delivery: inject high-priority messages
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      const { rows } = await pool.query<InboxRow>(`SELECT * FROM workbench.inbox_check($1)`, [mod]);
      if (rows.length > 0) {
        const msg = rows[0]!;
        await pool.query(
          `UPDATE workbench.agent_message SET status = 'acknowledged', acknowledged_at = now() WHERE id = $1 AND status = 'new'`,
          [msg.id],
        );
        const lines = [
          `[URGENT MESSAGE #${msg.id}] from:${msg.from_module} [${msg.msg_type}]: ${msg.subject}`,
          msg.priority === "high" ? `priority: HIGH` : null,
          msg.body ? `body: ${msg.body}` : null,
          msg.payload ? `payload: ${JSON.stringify(msg.payload)}` : null,
          msg.reply_to ? `reply_to: #${msg.reply_to}` : null,
          ``,
          `→ pg_msg_inbox module:${mod} to see full details`,
          `→ pg_msg_inbox module:${mod} resolve:${msg.id} resolution:"..." to resolve`,
        ].filter(Boolean);
        logHook(mod, tool_name, "inbox_delivery", true, `delivered msg #${msg.id}`);
        return res.json({
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            additionalContext: lines.join("\n"),
          },
        });
      }
    } catch {
      /* inbox_check table may not exist yet */
    }

    const mapping =
      moduleRegistry.resolveByName(mod) ?? moduleRegistry.resolve([mod]) ?? moduleRegistry.resolve([`${mod}_ut`]);
    const schemas = mapping?.schemas ?? [mod];

    // Server-level rule: Write/Edit must stay within module directory
    if (tool_name === "Write" || tool_name === "Edit") {
      const filePath = path.resolve((tool_input?.file_path ?? "") as string);
      const modulePath = mapping?.modulePath;
      if (modulePath && !filePath.startsWith(path.resolve(modulePath))) {
        log.warn({ mod, file: filePath, allowed: modulePath }, "hook: blocked file op outside module");
        return deny(
          res,
          `Module ${mod}: ${tool_name} interdit hors du repertoire du module (${modulePath}). Travaille uniquement dans le repertoire du module.`,
          mod,
          tool_name,
          filePath,
        );
      }
    }

    // Evaluate plugin-contributed hook rules
    const decision = evaluateHookRules(hookRules, tool_name, { module: mod, toolInput: tool_input ?? {}, schemas });
    if (decision?.action === "deny") {
      log.warn({ mod, tool: tool_name }, "hook: plugin denied");
      return deny(res, decision.reason, mod, tool_name);
    }

    allow(res, mod, tool_name);
  });

  // --- SessionStart ---
  app.post("/hooks/:module/session", async (req, res) => {
    const mod = req.params.module;
    try {
      const pool: import("pg").Pool = container.resolve("pool");
      const { rows } = await pool.query<PendingRow>(`SELECT * FROM workbench.inbox_pending($1)`, [mod]);
      if (rows.length > 0) {
        const lines = rows.map((r) => {
          const pri = r.priority === "high" ? " ⚡HIGH" : "";
          return `  #${r.id} [${r.msg_type}]${pri} from ${r.from_module}: ${r.subject}`;
        });
        return res.json({
          hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: `[INBOX] You have ${rows.length} pending message(s). Use pg_msg_inbox module:${mod} to read details and resolve.\n${lines.join("\n")}`,
          },
        });
      }
    } catch {
      /* Table might not exist yet */
    }
    res.json({ hookSpecificOutput: { hookEventName: "SessionStart" } });
  });

  // --- Stop ---
  const stopBlockCount = new Map<string, number>();

  app.post("/hooks/:module/stop", async (req, res) => {
    const mod = req.params.module;
    const count = stopBlockCount.get(mod) ?? 0;
    if (count >= 5) {
      stopBlockCount.delete(mod);
      return res.json({});
    }

    try {
      const pool: import("pg").Pool = container.resolve("pool");
      await pool.query(`SELECT * FROM workbench.ack_resolved($1)`, [mod]).catch(() => {});
      const { rows } = await pool.query<StopRow>(
        `SELECT id, from_module, msg_type, subject, priority, payload FROM workbench.agent_message WHERE to_module = $1 AND status = 'new' ORDER BY CASE WHEN priority = 'high' THEN 0 ELSE 1 END, created_at DESC LIMIT 1`,
        [mod],
      );
      if (rows.length > 0) {
        const msg = rows[0]!;
        await pool
          .query(
            `UPDATE workbench.agent_message SET status = 'acknowledged', acknowledged_at = now() WHERE id = $1 AND status = 'new'`,
            [msg.id],
          )
          .catch(() => {});
        const pri = msg.priority === "high" ? " [HIGH PRIORITY]" : "";
        stopBlockCount.set(mod, count + 1);
        const lines = [
          `NOUVELLE INSTRUCTION PRIORITAIRE — Message #${msg.id}${pri} de ${msg.from_module} [${msg.msg_type}]: ${msg.subject}`,
          msg.payload ? `payload: ${JSON.stringify(msg.payload)}` : null,
          `Action requise : pg_msg_inbox module:${mod} pour lire le message, puis pg_msg_inbox module:${mod} resolve:${msg.id} resolution:"..." une fois traité.`,
        ].filter(Boolean);
        return res.json({ decision: "block", reason: lines.join("\n") });
      }
    } catch {
      /* Table might not exist yet */
    }

    stopBlockCount.delete(mod);
    res.json({});
  });
}
