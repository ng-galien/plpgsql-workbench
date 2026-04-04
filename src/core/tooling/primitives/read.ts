export type ReadCompleteness = "full" | "partial";

export interface ReadDocument {
  uri?: string;
  completeness?: ReadCompleteness;
  body: string;
  next?: string[];
}

export interface ReadSection {
  title: string;
  lines: string[];
}

export function formatReadDocument(document: ReadDocument): string {
  const parts: string[] = [];
  if (document.uri) parts.push(`uri: ${document.uri}`);
  parts.push(`completeness: ${document.completeness ?? "full"}`);
  parts.push("", document.body);
  if (document.next && document.next.length > 0) {
    parts.push("", "next:");
    for (const item of document.next) parts.push(`  - ${item}`);
  }
  return parts.join("\n");
}

export function formatReadSections(
  sections: ReadSection[],
  options: { completeness?: ReadCompleteness; next?: string[] } = {},
): string {
  if (sections.length === 0) {
    return formatReadDocument({
      completeness: options.completeness ?? "full",
      body: "no matches",
      next: options.next,
    });
  }

  const body = sections.map((section) => `${section.title}:\n${section.lines.join("\n")}`).join("\n\n");

  return formatReadDocument({
    completeness: options.completeness ?? "full",
    body,
    next: options.next,
  });
}
