// ============================================================
// CLIPBOARD — Copy, Paste, Duplicate
// ============================================================

import { store, dispatch, selectedElements } from "./store/index.js";
import { sendPasteElements, sendDelete, sendAddElement, onNextStateUpdate } from "./ws.js";
import { undoManager } from "./history.js";
import { showToast } from "./toast.js";

let clipboard: any[] = [];

export function copySelected(): void {
  const els = selectedElements(store.state);
  if (els.length === 0) return;
  clipboard = els.map(el => {
    const c = structuredClone(el) as any;
    delete c.href;
    return c;
  });
  showToast(els.length > 1 ? `${els.length} copiés` : "Copié");
}

export function pasteClipboard(): void {
  const currentDoc = store.state.doc.currentDoc;
  if (clipboard.length === 0 || !currentDoc) return;
  const pasted = clipboard.map(el => {
    const p = structuredClone(el);
    if (p.type === "line") {
      p.x1 += 5; p.y1 += 5;
      p.x2 += 5; p.y2 += 5;
    } else {
      p.x += 5; p.y += 5;
    }
    delete p.id;
    delete p.href;
    return p;
  });
  const prevCount = currentDoc.elements.length;
  sendPasteElements(pasted);
  // Push undo and select new elements after server assigns new IDs
  onNextStateUpdate(() => {
    const doc = store.state.doc.currentDoc;
    if (!doc) return;
    const newEls = doc.elements.slice(prevCount);
    for (const newEl of newEls) {
      const clone = structuredClone(newEl) as any;
      delete clone.href;
      undoManager.push({
        label: `Paste ${newEl.id}`,
        undo: () => sendDelete(newEl.id),
        redo: () => sendAddElement(clone),
      });
    }
    // Select all pasted elements
    if (newEls.length > 0) {
      dispatch({ type: "SELECT_ELEMENT", id: newEls[0].id });
      for (let i = 1; i < newEls.length; i++) {
        dispatch({ type: "SELECT_ELEMENT", id: newEls[i].id, toggle: true });
      }
    }
  });
}

export function duplicateSelected(): void {
  copySelected();
  pasteClipboard();
}
