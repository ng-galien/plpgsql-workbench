/**
 * pg_broadcast — Send real-time notifications to the browser.
 *
 * Uses Supabase Broadcast channel to push toast/card/progress/dialog
 * to the pgView shell. Optionally persists to workbench.agent_message.
 */

import { z } from "zod";
import type { BroadcastFn } from "../../core/broadcast.js";
import type { ToolHandler } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createBroadcastTool({ broadcast }: { broadcast: BroadcastFn }): ToolHandler {
  return {
    metadata: {
      name: "pg_broadcast",
      description:
        "Send a real-time notification to the browser.\n" +
        "Toast, card, progress bar, or navigation command.\n" +
        "The user sees it instantly in the pgView shell.",
      schema: z.object({
        msg: z.string().describe("Notification title"),
        detail: z.string().optional().describe("Subtitle / description"),
        href: z.string().optional().describe("Link URL (shows 'Ouvrir →' button)"),
        level: z.enum(["info", "success", "warning", "error"]).optional().describe("Toast level (default: info)"),
        action: z.enum(["navigate"]).optional().describe("'navigate' = auto-navigate to href, no toast"),
        type: z.enum(["toast", "card", "progress", "dialog"]).optional().describe("Display type (default: toast)"),
        progress: z.number().min(0).max(100).optional().describe("Progress bar percentage (0-100)"),
        badge: z.string().optional().describe("Badge label"),
        persist: z.boolean().optional().describe("Also store in workbench.agent_message (default: false)"),
      }),
    },
    handler: async (args) => {
      await broadcast({
        msg: args.msg as string,
        detail: args.detail as string | undefined,
        href: args.href as string | undefined,
        level: args.level as "info" | "success" | "warning" | "error" | undefined,
        action: args.action as "navigate" | undefined,
        type: args.type as "toast" | "card" | "progress" | "dialog" | undefined,
        progress: args.progress as number | undefined,
        badge: args.badge as string | undefined,
        persist: args.persist as boolean | undefined,
      });

      return text(`broadcast sent: ${args.msg}`);
    },
  };
}
