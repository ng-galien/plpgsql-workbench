import { z } from "zod";
import type { ToolHandler } from "../../container.js";
import { text } from "../../helpers.js";
import type { GmailClient } from "./auth.js";
import { ensureGmailConnected } from "./auth.js";

function extractBody(payload: any): string {
  let body = "";
  if (payload.body?.data && payload.mimeType === "text/plain") {
    return Buffer.from(payload.body.data, "base64url").toString("utf-8");
  }
  if (payload.parts) {
    for (const part of payload.parts) {
      body = extractBody(part);
      if (body) return body;
    }
  }
  if (!body && payload.body?.data && payload.mimeType === "text/html") {
    const html = Buffer.from(payload.body.data, "base64url").toString("utf-8");
    return html
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }
  return body;
}

interface Attachment {
  id: string;
  filename: string;
  mimeType: string;
  size: number;
}

function collectAttachments(payload: any): Attachment[] {
  const attachments: Attachment[] = [];
  if (payload.filename && payload.filename.length > 0 && payload.body?.attachmentId) {
    attachments.push({
      id: payload.body.attachmentId,
      filename: payload.filename,
      mimeType: payload.mimeType || "application/octet-stream",
      size: payload.body.size || 0,
    });
  }
  if (payload.parts) {
    for (const part of payload.parts) attachments.push(...collectAttachments(part));
  }
  return attachments;
}

export function createGmailReadTool({ gmailClient }: { gmailClient: GmailClient }): ToolHandler {
  return {
    metadata: {
      name: "gmail_read",
      description:
        "Read a full Gmail message by ID.\n" +
        "Returns headers, body (plain text preferred), and attachment list.\n" +
        "Use gmail_search to find message IDs first.",
      schema: z.object({
        message_id: z.string().describe("Gmail message ID (from gmail_search results)"),
      }),
    },
    handler: async (args, _extra) => {
      const messageId = args.message_id as string;

      let gmail: Awaited<ReturnType<typeof ensureGmailConnected>> | undefined;
      try {
        gmail = await ensureGmailConnected(gmailClient);
      } catch (err) {
        return text(
          `problem: Gmail auth failed: ${(err as Error).message}\nwhere: gmail_read\nfix_hint: check workbench.config(google, *)`,
        );
      }

      const detail = await gmail.users.messages.get({
        userId: "me",
        id: messageId,
        format: "full",
      });

      const headers = detail.data.payload?.headers || [];
      const from = headers.find((h: any) => h.name === "From")?.value || "";
      const to = headers.find((h: any) => h.name === "To")?.value || "";
      const subject = headers.find((h: any) => h.name === "Subject")?.value || "";
      const date = headers.find((h: any) => h.name === "Date")?.value || "";

      const body = extractBody(detail.data.payload);
      const attachments = collectAttachments(detail.data.payload);

      const truncated = body.length > 3000;
      const parts: string[] = [
        `message: ${messageId}`,
        `completeness: ${truncated ? "partial" : "full"}`,
        `from: ${from}`,
        `to: ${to}`,
        `subject: ${subject}`,
        `date: ${date}`,
      ];

      if (attachments.length > 0) {
        parts.push("");
        parts.push(`attachments (${attachments.length}):`);
        for (const a of attachments) {
          const sizeStr = a.size < 1024 ? `${a.size}B` : `${(a.size / 1024).toFixed(0)}KB`;
          parts.push(`  ${a.filename.padEnd(40)} ${a.mimeType.padEnd(30)} ${sizeStr}  id:${a.id}`);
        }
      }

      // Truncate body
      const maxBody = 3000;
      const displayBody = truncated ? body.slice(0, maxBody) : body;
      parts.push("");
      parts.push("body:");
      for (const line of displayBody.split("\n")) {
        parts.push(`  ${line}`);
      }
      if (truncated) parts.push(`  ... (${body.length - maxBody} chars remaining)`);

      parts.push("");
      parts.push("next:");
      if (attachments.length > 0) {
        parts.push(`  - gmail_attachment message_id:${messageId} attachment_id:${attachments[0].id}`);
      }

      return text(parts.join("\n"));
    },
  };
}
