// ============================================================
// HISTORY — Undo/Redo (command pattern)
// ============================================================

import { subscribeToSelector, activeDocName } from "./store/index.js";

export interface Command {
  undo: () => void;
  redo: () => void;
  label: string;
  mergeId?: string;
}

class UndoManager {
  private undoStack: Command[] = [];
  private redoStack: Command[] = [];
  private maxHistory = 50;
  private lastPushTime = 0;

  push(cmd: Command): void {
    // Merge consecutive commands with same mergeId within 500ms (e.g. arrow key nudge)
    if (cmd.mergeId && this.undoStack.length > 0) {
      const last = this.undoStack[this.undoStack.length - 1];
      if (last.mergeId === cmd.mergeId && Date.now() - this.lastPushTime < 500) {
        last.redo = cmd.redo;
        last.label = cmd.label;
        this.lastPushTime = Date.now();
        return;
      }
    }
    this.undoStack.push(cmd);
    if (this.undoStack.length > this.maxHistory) this.undoStack.shift();
    this.redoStack.length = 0;
    this.lastPushTime = Date.now();
  }

  undo(): void {
    const cmd = this.undoStack.pop();
    if (!cmd) return;
    cmd.undo();
    this.redoStack.push(cmd);
  }

  redo(): void {
    const cmd = this.redoStack.pop();
    if (!cmd) return;
    cmd.redo();
    this.undoStack.push(cmd);
  }

  canUndo(): boolean { return this.undoStack.length > 0; }
  canRedo(): boolean { return this.redoStack.length > 0; }
  clear(): void { this.undoStack.length = 0; this.redoStack.length = 0; }
}

export const undoManager = new UndoManager();

// Clear history on document change
subscribeToSelector(activeDocName, () => { undoManager.clear(); });
