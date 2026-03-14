// ============================================================
// STORE TYPES — immutable state shape, phases
// ============================================================

import type { Document, DocSummary, AssetsData } from "../types.js";
import type { Guide } from "../snap.js";

/** Server-authoritative document data. Replaced wholesale on WS state message. */
export interface DocumentSlice {
  currentDoc: Document | null;
  docList: DocSummary[];
}

/** Client-only persistent UI state. Survives document changes. */
export interface UISlice {
  selectedIds: string[];
  layersPanelCollapsed: boolean;
  propsPanelCollapsed: boolean;
  photoCollapsed: boolean;
  photoSavedH: number;
  showNames: boolean;
  showBleed: boolean;
  snapEnabled: boolean;
  documentLocked: boolean;
  assetsData: AssetsData | null;
}

/** Transient state during interactions. Never persisted. */
export interface EphemeralSlice {
  snapGuides: Guide[];
  zoomLevel: number;
}

/** Non-serializable references. */
export interface RefsSlice {
  ws: WebSocket | null;
  zoomBehavior: any;
  lastFitKey: string | null;
}

/** Application lifecycle phase (state machine). */
export type AppPhase =
  | "loading"
  | "idle"
  | "selected"
  | "dragging"
  | "editing_prop"
  | "loading_doc";

/** The complete immutable state tree. */
export interface AppState {
  doc: DocumentSlice;
  ui: UISlice;
  ephemeral: EphemeralSlice;
  refs: RefsSlice;
  phase: AppPhase;
}
