import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocPeekTool({
  withClient,
  peekTool,
}: {
  withClient: WithClient;
  peekTool: ToolHandler;
}): ToolHandler {
  return {
    metadata: {
      name: "doc_peek",
      description:
        "Read a document: file content + full classification (labels, entities, relations).\n" +
        "Combines docman.peek() for metadata and fs_peek for content.",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        page: z.number().optional().describe("Page number for paginated content (default 1)"),
      }),
    },
    handler: async (args, extra) => {
      const { id, page } = args as { id: string; page?: number };

      // 1. Get classification from docman.peek()
      const doc = await withClient(async (client) => {
        const res = await client.query(`SELECT docman.peek($1)`, [id]);
        return res.rows[0]?.peek;
      });

      if (!doc || doc.error) {
        return text(`problem: document not found\nwhere: id ${id}\nfix_hint: use doc_inbox or doc_search`);
      }

      // 2. Read file content via fs_peek
      const contentResult = await peekTool.handler(
        { path: doc.file_path, page: page ?? 1 },
        extra,
      );
      const contentText = contentResult.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text)
        .join("\n");

      // 3. Format output
      const lines = [
        `id: ${doc.id}`,
        `file: ${doc.filename}${doc.extension || ""}  ${Math.round((doc.size_bytes ?? 0) / 1024)}KB  ${doc.mime_type || ""}`,
        `type: ${doc.doc_type || "untyped"}`,
        `date: ${doc.document_date || "unknown"}`,
        `source: ${doc.source}${doc.source_ref ? ` (${doc.source_ref})` : ""}`,
        `classified: ${doc.classified_at ? "yes" : "no"}`,
      ];

      if (doc.summary) lines.push(`summary: ${doc.summary}`);

      // Labels
      if (doc.labels?.length > 0) {
        const lbls = doc.labels.map((l: any) =>
          `${l.name} (${l.kind}) [${l.confidence}${l.assigned_by === "user" ? " user" : ""}]`
        );
        lines.push(`labels: ${lbls.join(", ")}`);
      } else {
        lines.push("labels: none");
      }

      // Entities
      if (doc.entities?.length > 0) {
        const ents = doc.entities.map((e: any) =>
          `${e.name} (${e.kind}:${e.role}) [${e.confidence}]`
        );
        lines.push(`entities: ${ents.join(", ")}`);
      } else {
        lines.push("entities: none");
      }

      // Relations
      if (doc.relations?.length > 0) {
        const rels = doc.relations.map((r: any) =>
          `${r.direction} ${r.kind} -> ${r.related_file} [${r.confidence}]`
        );
        lines.push(`relations: ${rels.join(", ")}`);
      } else {
        lines.push("relations: none");
      }

      return text(
        lines.join("\n") +
        `\n---\n${contentText}`
      );
    },
  };
}
