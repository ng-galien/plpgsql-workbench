// ============================================================
// STORE EVENTS — typed discriminated union of all mutations
// ============================================================

import type { Document, DocSummary, AssetsData } from "../types.js";
import type { Guide } from "../snap.js";
import type { AppPhase } from "./types.js";

/** Document events (from server). */
export type DocEvent =
  | { type: "SERVER_STATE"; doc: Document | null; docList: DocSummary[] };

/** UI events (client-local interactions). */
export type UIEvent =
  | { type: "SELECT_ELEMENT"; id: string | null; toggle?: boolean }
  | { type: "TOGGLE_LAYERS_PANEL" }
  | { type: "TOGGLE_PROPS_PANEL" }
  | { type: "TOGGLE_PHOTO_PANEL" }
  | { type: "SET_PHOTO_SAVED_H"; height: number }
  | { type: "TOGGLE_SHOW_NAMES" }
  | { type: "TOGGLE_SHOW_BLEED" }
  | { type: "TOGGLE_SNAP" }
  | { type: "TOGGLE_LOCK_DOC" }
  | { type: "SET_ASSETS"; assets: AssetsData };

/** Ephemeral events (drag lifecycle). */
export type EphemeralEvent =
  | { type: "DRAG_START"; elId: string }
  | { type: "DRAG_MOVE"; snapGuides: Guide[] }
  | { type: "DRAG_END" }
  | { type: "SET_ZOOM_LEVEL"; level: number };

/** Ref events (non-serializable singletons). */
export type RefEvent =
  | { type: "SET_WS"; ws: WebSocket | null }
  | { type: "SET_ZOOM_BEHAVIOR"; behavior: any }
  | { type: "SET_LAST_FIT_KEY"; key: string | null };

/** Phase transitions. */
export type PhaseEvent =
  | { type: "PHASE_TRANSITION"; to: AppPhase };

/** Union of all events the store can process. */
export type AppEvent = DocEvent | UIEvent | EphemeralEvent | RefEvent | PhaseEvent;
