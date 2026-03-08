import { z } from "zod";
import fs from "fs";
import path from "path";
import os from "os";
import type { ToolHandler } from "../../container.js";
import { text } from "../../helpers.js";
import type { GmailClient } from "./auth.js";
import { ensureGmailConnected } from "./auth.js";

export function createGmailAttachmentTool({ gmailClient }: {
  gmailClient: GmailClient;
}): ToolHandler {
  return {
    metadata: {
      name: "gmail_attachment",
      description:
        "Download a Gmail attachment to the local filesystem.\n" +
        "Saves to <inbox_root>/<mail-slug>/<original-filename>.\n" +
        "The mail-slug is derived from the message subject.\n" +
        "Use gmail_read to find attachment IDs first.",
      schema: z.object({
        message_id: z.string().describe("Gmail message ID"),
        attachment_id: z.string().describe("Attachment ID (from gmail_read results)"),
      }),
    },
    handler: async (args, _extra) => {
      const messageId = args.message_id as string;
      const attachmentId = args.attachment_id as string;

      const inboxRoot = gmailClient.config.inboxRoot;
      if (!inboxRoot) {
        return text("problem: inbox_root not configured\nwhere: gmail_attachment\nfix_hint: set GMAIL_INBOX_ROOT or configure inboxRoot in google pack");
      }
      const resolvedRoot = path.resolve(inboxRoot.replace(/^~/, os.homedir()));

      let gmail;
      try {
        gmail = await ensureGmailConnected(gmailClient);
      } catch (err) {
        return text(`problem: Gmail auth failed: ${(err as Error).message}\nwhere: gmail_attachment\nfix_hint: check GOOGLE_CREDENTIALS_PATH and token`);
      }

      // Fetch message metadata for subject
      const detail = await gmail.users.messages.get({
        userId: "me",
        id: messageId,
        format: "metadata",
        metadataHeaders: ["Subject"],
      });
      const headers = detail.data.payload?.headers || [];
      const subject = headers.find((h: any) => h.name === "Subject")?.value || "no-subject";
      const mailSlug = subject
        .replace(/[^a-zA-Z0-9àâäéèêëïîôùûüÿçœæ\s-]/g, "")
        .trim()
        .replace(/\s+/g, "-")
        .toLowerCase()
        .slice(0, 80);

      // Find attachment filename from message parts
      let originalFilename = "attachment";
      function findFilename(payload: any): void {
        if (payload.body?.attachmentId === attachmentId && payload.filename) {
          originalFilename = payload.filename;
          return;
        }
        if (payload.parts) {
          for (const part of payload.parts) findFilename(part);
        }
      }
      const fullDetail = await gmail.users.messages.get({
        userId: "me",
        id: messageId,
        format: "full",
      });
      findFilename(fullDetail.data.payload);

      const safeFilename = path.basename(originalFilename);
      const dir = path.join(resolvedRoot, mailSlug);
      const filePath = path.join(dir, safeFilename);

      // Check if file already exists
      if (fs.existsSync(filePath)) {
        return text(`file already exists: ${filePath}`);
      }

      // Download attachment
      const attachment = await gmail.users.messages.attachments.get({
        userId: "me",
        messageId,
        id: attachmentId,
      });

      const data = attachment.data.data;
      if (!data) {
        return text(`problem: attachment ${attachmentId} has no data\nwhere: gmail_attachment\nfix_hint: verify the attachment_id from gmail_read`);
      }

      const buffer = Buffer.from(data, "base64url");

      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(filePath, buffer);

      const size = buffer.length;
      const sizeStr = size < 1024 ? `${size}B` : size < 1024 * 1024 ? `${(size / 1024).toFixed(0)}KB` : `${(size / (1024 * 1024)).toFixed(1)}MB`;

      const parts: string[] = [
        `saved: ${filePath}`,
        `completeness: full`,
        `filename: ${safeFilename}`,
        `size: ${sizeStr}`,
        "",
        "next:",
        `  - fs_peek path:${filePath}`,
      ];

      return text(parts.join("\n"));
    },
  };
}
