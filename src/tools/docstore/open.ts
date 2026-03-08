import { z } from "zod";
import os from "os";
import { existsSync, statSync } from "fs";
import path from "path";
import { execFileSync } from "child_process";
import type { ToolHandler } from "../../container.js";
import { text } from "../../helpers.js";

export function createOpenTool(): ToolHandler {
  return {
    metadata: {
      name: "fs_open",
      description:
        "Open a file or directory with the system default application.\n" +
        "Uses: open (macOS), xdg-open (Linux), start (Windows).\n" +
        "Read-only — never modifies the file.",
      schema: z.object({
        path: z.string().describe("Absolute path to file or directory"),
      }),
    },
    handler: async (args, _extra) => {
      const filePath = path.resolve(args.path as string);
      if (!existsSync(filePath)) return text(`problem: path not found: ${filePath}\nwhere: fs_open\nfix_hint: check the path argument`);

      const isDir = statSync(filePath).isDirectory();
      const platform = os.platform();

      try {
        if (platform === "darwin") {
          execFileSync("open", [filePath]);
        } else if (platform === "win32") {
          execFileSync("cmd", ["/c", "start", "", filePath]);
        } else {
          execFileSync("xdg-open", [filePath]);
        }
      } catch (err) {
        return text(`problem: open failed: ${err instanceof Error ? err.message : String(err)}\nwhere: fs_open\nfix_hint: check file permissions or default application`);
      }

      const kind = isDir ? "directory" : "file";
      const parts = [
        `✓ opened ${kind}: ${filePath}`,
        `completeness: full`,
        "",
        "next:",
      ];
      if (isDir) {
        parts.push(`  - fs_scan path:${filePath}`);
      } else {
        parts.push(`  - fs_peek path:${filePath}`);
      }
      return text(parts.join("\n"));
    },
  };
}
