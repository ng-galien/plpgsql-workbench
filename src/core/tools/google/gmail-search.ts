import { z } from "zod";
import type { ToolHandler } from "../../container.js";
import { text } from "../../helpers.js";
import type { GmailClient } from "./auth.js";
import { ensureGmailConnected } from "./auth.js";

export function createGmailSearchTool({ gmailClient }: {
  gmailClient: GmailClient;
}): ToolHandler {
  return {
    metadata: {
      name: "gmail_search",
      description:
        "Search Gmail messages using Gmail query syntax.\n" +
        "Returns message list with id, snippet, date, from, subject.\n" +
        "Use gmail_read to get the full message body.\n" +
        "\n" +
        "Query examples:\n" +
        '  from:amazon subject:facture\n' +
        '  has:attachment newer_than:3m\n' +
        '  label:inbox is:unread',
      schema: z.object({
        query: z.string().describe("Gmail search query (same syntax as Gmail search bar)"),
        limit: z.number().optional().describe("Max results (default: 10, max: 50)"),
      }),
    },
    handler: async (args, _extra) => {
      const q = args.query as string;
      const maxResults = Math.min((args.limit as number | undefined) ?? 10, 50);

      let gmail;
      try {
        gmail = await ensureGmailConnected(gmailClient);
      } catch (err) {
        return text(`problem: Gmail auth failed: ${(err as Error).message}\nwhere: gmail_search\nfix_hint: check workbench.config(google, *)`);
      }

      const listRes = await gmail.users.messages.list({ userId: "me", q, maxResults });
      const messages = listRes.data.messages || [];

      if (messages.length === 0) {
        return text(`query: ${q}\ncompleteness: full\n\nno messages found`);
      }

      const parts: string[] = [`query: ${q}`, `completeness: full`, `results: ${messages.length}`, ""];

      for (const msg of messages) {
        const detail = await gmail.users.messages.get({
          userId: "me",
          id: msg.id!,
          format: "metadata",
          metadataHeaders: ["From", "Subject", "Date"],
        });
        const headers = detail.data.payload?.headers || [];
        const from = headers.find((h: any) => h.name === "From")?.value || "";
        const subject = headers.find((h: any) => h.name === "Subject")?.value || "";
        const date = headers.find((h: any) => h.name === "Date")?.value || "";
        const snippet = detail.data.snippet || "";
        const hasAttach = (detail.data.payload?.parts || []).some(
          (p: any) => p.filename && p.filename.length > 0,
        );

        parts.push(`message: ${msg.id}`);
        parts.push(`  from: ${from}`);
        parts.push(`  subject: ${subject}`);
        parts.push(`  date: ${date}`);
        if (hasAttach) parts.push(`  attachments: yes`);
        parts.push(`  snippet: ${snippet}`);
        parts.push("");
      }

      parts.push("next:");
      parts.push(`  - gmail_read message_id:${messages[0].id}`);

      return text(parts.join("\n"));
    },
  };
}
