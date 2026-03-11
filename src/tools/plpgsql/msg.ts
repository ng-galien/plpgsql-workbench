import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

const MSG_TYPES = ["feature_request", "bug_report", "breaking_change", "question", "info"] as const;

export function createMsgTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_msg",
      description:
        "Send a message to another module agent.\n" +
        "Use for cross-module requests, notifications, and coordination.\n" +
        "Target a specific module or '*' for broadcast.",
      schema: z.object({
        from: z.string().describe("Your module name. Ex: cad3d, pgv"),
        to: z.string().describe("Target module name, or '*' for broadcast"),
        type: z.enum(MSG_TYPES).describe("Message category"),
        subject: z.string().describe("Short summary (one line)"),
        body: z.string().optional().describe("Detailed description, context, code references"),
      }),
    },
    handler: async (args, _extra) => {
      const from = args.from as string;
      const to = args.to as string;
      const type = args.type as string;
      const subject = args.subject as string;
      const body = (args.body as string) || null;

      return withClient(async (client) => {
        await ensureTable(client);
        const { rows } = await client.query(
          `INSERT INTO workbench.agent_message (from_module, to_module, msg_type, subject, body)
           VALUES ($1, $2, $3, $4, $5) RETURNING id, created_at`,
          [from, to, type, subject, body],
        );
        const msg = rows[0];
        const lines = [
          `msg #${msg.id} sent`,
          `from: ${from} -> ${to}`,
          `type: ${type}`,
          `subject: ${subject}`,
          `status: new`,
          `created_at: ${msg.created_at}`,
          "",
          `next: pg_msg_inbox module:${from}`,
        ];
        return text(lines.join("\n"));
      });
    },
  };
}

export function createMsgInboxTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_msg_inbox",
      description:
        "Read pending messages for your module, or resolve a message.\n" +
        "Without resolve: lists messages and auto-acknowledges new ones.\n" +
        "With resolve: marks a message as resolved with optional note.\n" +
        "With sent: true, shows messages YOU sent and their resolution status.",
      schema: z.object({
        module: z.string().describe("Your module name (comma-separated for aliases). Ex: cad3d, pgv, lead,workbench"),
        resolve: z.number().optional().describe("Message ID to mark as resolved"),
        resolution: z.string().optional().describe("Resolution note (when resolving)"),
        sent: z.boolean().optional().describe("Show messages sent by you (track resolutions)"),
        status: z.enum(["new", "acknowledged", "resolved", "all"]).optional()
          .describe("Filter by status (default: new + acknowledged)"),
        limit: z.number().optional().describe("Max messages (default: 20)"),
      }),
    },
    handler: async (args, _extra) => {
      const names = (args.module as string).split(",").map(s => s.trim());
      const mod = names[0];
      const resolveId = args.resolve as number | undefined;
      const resolution = (args.resolution as string) || null;
      const showSent = args.sent as boolean | undefined;
      const statusFilter = (args.status as string) || null;
      const limit = (args.limit as number) || 20;

      return withClient(async (client) => {
        await ensureTable(client);

        // Resolve mode
        if (resolveId !== undefined) {
          const ph = names.map((_, i) => `$${i + 3}`).join(", ");
          const { rows } = await client.query(
            `UPDATE workbench.agent_message
             SET status = 'resolved', resolved_at = now(), resolution = $1
             WHERE id = $2 AND (to_module IN (${ph}) OR to_module = '*')
             RETURNING id, from_module, to_module, msg_type, subject, resolution`,
            [resolution, resolveId, ...names],
          );
          if (rows.length === 0) {
            return text(`problem: message #${resolveId} not found or not addressed to ${mod}`);
          }
          const r = rows[0];
          const lines = [
            `msg #${r.id} resolved`,
            `from: ${r.from_module} -> ${r.to_module}`,
            `type: ${r.msg_type}`,
            `subject: ${r.subject}`,
            r.resolution ? `resolution: ${r.resolution}` : null,
            "",
            `next: pg_msg_inbox module:${mod}`,
          ].filter(Boolean);
          return text(lines.join("\n"));
        }

        // Sent mode — show messages sent by this module + ack resolutions
        if (showSent) {
          const ph = names.map((_, i) => `$${i + 1}`).join(", ");
          const { rows } = await client.query(
            `SELECT id, to_module, msg_type, subject, status, resolution, created_at, resolved_at
             FROM workbench.agent_message
             WHERE from_module IN (${ph})
             ORDER BY created_at DESC LIMIT $${names.length + 1}`,
            [...names, limit],
          );

          // Mark resolved notifications as seen (so Stop hook won't re-notify)
          const resolvedIds = rows
            .filter((r: any) => r.status === "resolved" && r.resolved_at > r.acknowledged_at)
            .map((r: any) => r.id);
          if (resolvedIds.length > 0) {
            await client.query(
              `UPDATE workbench.agent_message SET acknowledged_at = resolved_at WHERE id = ANY($1)`,
              [resolvedIds],
            );
          }

          if (rows.length === 0) {
            return text(`sent: ${mod} (0 messages)\n\nno sent messages`);
          }

          const lines = [`sent: ${mod} (${rows.length} messages)`, ""];
          for (const r of rows) {
            const date = new Date(r.created_at).toISOString().slice(0, 16).replace("T", " ");
            const status = r.status.toUpperCase();
            lines.push(`#${r.id} -> ${r.to_module} [${r.msg_type}] ${status}  ${date}`);
            lines.push(`  subject: ${r.subject}`);
            if (r.resolution) lines.push(`  resolution: ${r.resolution}`);
            lines.push("");
          }
          return text(lines.join("\n"));
        }

        // Inbox mode — build WHERE clause
        let statusClause: string;
        if (statusFilter === "all") {
          statusClause = "1=1";
        } else if (statusFilter === "new" || statusFilter === "acknowledged" || statusFilter === "resolved") {
          statusClause = `status = '${statusFilter}'`;
        } else {
          statusClause = "status IN ('new', 'acknowledged')";
        }

        const ph = names.map((_, i) => `$${i + 1}`).join(", ");
        const { rows } = await client.query(
          `SELECT id, from_module, msg_type, subject, body, status, created_at
           FROM workbench.agent_message
           WHERE (to_module IN (${ph}) OR to_module = '*') AND ${statusClause}
           ORDER BY created_at DESC LIMIT $${names.length + 1}`,
          [...names, limit],
        );

        // Auto-acknowledge new messages
        const newIds = rows.filter((r: any) => r.status === "new").map((r: any) => r.id);
        if (newIds.length > 0) {
          await client.query(
            `UPDATE workbench.agent_message SET status = 'acknowledged', acknowledged_at = now()
             WHERE id = ANY($1)`,
            [newIds],
          );
        }

        if (rows.length === 0) {
          return text(`inbox: ${mod} (0 messages)\n\nno pending messages\n\nnext: pg_msg from:${mod} to:... type:... subject:...`);
        }

        const newCount = newIds.length;
        const ackCount = rows.filter((r: any) => r.status === "acknowledged").length;
        const counts = [
          newCount > 0 ? `${newCount} new` : null,
          ackCount > 0 ? `${ackCount} acknowledged` : null,
        ].filter(Boolean).join(", ");

        const lines = [`inbox: ${mod} (${counts || rows.length + " messages"})`, ""];

        for (const r of rows) {
          const status = r.status === "new" ? "NEW" : r.status.toUpperCase();
          const date = new Date(r.created_at).toISOString().slice(0, 16).replace("T", " ");
          lines.push(`#${r.id} [${r.msg_type}] ${status}  ${date}`);
          lines.push(`  from: ${r.from_module}`);
          lines.push(`  subject: ${r.subject}`);
          if (r.body) {
            lines.push(`  body: ${r.body}`);
          }
          lines.push("");
        }

        lines.push(`next:`);
        if (newIds.length > 0) {
          lines.push(`  pg_msg_inbox module:${mod} resolve:${rows[0].id} resolution:"..."`);
        }
        lines.push(`  pg_msg from:${mod} to:... type:... subject:...`);

        return text(lines.join("\n"));
      });
    },
  };
}

async function ensureTable(client: import("../../connection.js").DbClient): Promise<void> {
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.agent_message (
      id              SERIAL PRIMARY KEY,
      from_module     TEXT NOT NULL,
      to_module       TEXT NOT NULL,
      msg_type        TEXT NOT NULL CHECK (msg_type IN (
                        'feature_request','bug_report','breaking_change','question','info')),
      subject         TEXT NOT NULL,
      body            TEXT,
      status          TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','acknowledged','resolved')),
      resolution      TEXT,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      acknowledged_at TIMESTAMPTZ,
      resolved_at     TIMESTAMPTZ
    )
  `);
}
