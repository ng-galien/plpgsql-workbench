import fsSync from "node:fs";
import pathMod from "node:path";

/** Walk up from cwd to find the workspace root (has modules/ or runtime/). */
export function resolveWorkspaceRoot(): string {
  let dir = process.cwd();
  for (let i = 0; i < 10; i++) {
    if (fsSync.existsSync(pathMod.join(dir, "modules")) || fsSync.existsSync(pathMod.join(dir, "runtime"))) {
      return dir;
    }
    dir = pathMod.dirname(dir);
  }
  return process.cwd();
}
