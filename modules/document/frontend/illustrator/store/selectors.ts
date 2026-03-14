// ============================================================
// STORE SELECTORS — derived state
// ============================================================

import type { AppState } from "./types.js";
import type { Element } from "../types.js";
import { findInElements } from "../helpers.js";

export function selectedElements(s: AppState): Element[] {
  if (s.ui.selectedIds.length === 0 || !s.doc.currentDoc) return [];
  const out: Element[] = [];
  for (const id of s.ui.selectedIds) {
    const el = findInElements(s.doc.currentDoc.elements, id);
    if (el) out.push(el);
  }
  return out;
}

export function activeDocName(s: AppState): string | null {
  return s.doc.currentDoc?.name ?? null;
}
