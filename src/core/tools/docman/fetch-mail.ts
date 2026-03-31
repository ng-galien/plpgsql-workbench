import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocFetchMailTool({
  withClient,
  gmailSearchTool,
  gmailAttachmentTool,
  gmailReadTool,
}: {
  withClient: WithClient;
  gmailSearchTool: ToolHandler;
  gmailAttachmentTool: ToolHandler;
  gmailReadTool: ToolHandler;
}): ToolHandler {
  return {
    metadata: {
      name: "doc_fetch_mail",
      description:
        "Fetch email attachments and import them for classification.\n" +
        "Searches Gmail, downloads attachments, registers in docman.\n" +
        "Uses Gmail query syntax (same as gmail_search).",
      schema: z.object({
        query: z.string().describe("Gmail search query (e.g. 'has:attachment from:edf')"),
        limit: z.number().optional().describe("Max emails to process (default 10)"),
      }),
    },
    handler: async (args, extra) => {
      const { query, limit = 10 } = args as { query: string; limit?: number };

      // 1. Search emails
      const searchResult = await gmailSearchTool.handler({ query, limit }, extra);
      const searchText = searchResult.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text)
        .join("\n");

      const messageIds = [...searchText.matchAll(/^message: (.+)$/gm)].map((m) => m[1]!.trim());

      if (messageIds.length === 0) {
        return text(`No emails found for: ${query}`);
      }

      // 2. Read each message, download attachments
      let fetched = 0;
      for (const msgId of messageIds) {
        const readResult = await gmailReadTool.handler({ message_id: msgId }, extra);
        const readText = readResult.content
          .filter((c: any) => c.type === "text")
          .map((c: any) => c.text)
          .join("\n");

        const attachments = [...readText.matchAll(/attachment: (.+?) \| id: (.+)$/gm)].map((m) => ({
          filename: m[1]!.trim(),
          attachmentId: m[2]!.trim(),
        }));

        for (const att of attachments) {
          await gmailAttachmentTool.handler({ message_id: msgId, attachment_id: att.attachmentId }, extra);
          fetched++;
        }
      }

      // 3. Register downloaded files via PL/pgSQL
      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.register(NULL, 'email')`);
        const { registered } = res.rows[0];

        return text(
          `Fetched from ${messageIds.length} emails\n` +
            `attachments: ${fetched} downloaded, ${registered} new in docman\n\n` +
            `next:\n  - doc_inbox\n  - doc_search source:email`,
        );
      });
    },
  };
}
