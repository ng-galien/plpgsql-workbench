// ============================================================
// STORE GUARDS — state machine middleware
// ============================================================

import type { AppState } from "./types.js";
import type { AppEvent } from "./events.js";
import type { Middleware } from "./store.js";

/**
 * Transition table: which events are allowed in which phases.
 * "*" means allowed in all phases.
 */
const ALLOWED: Record<string, Set<string> | "*"> = {
  // Server + refs always pass
  SERVER_STATE: "*",
  SET_WS: "*",
  SET_ZOOM_BEHAVIOR: "*",
  SET_LAST_FIT_KEY: "*",
  PHASE_TRANSITION: "*",

  // Selection blocked during drag
  SELECT_ELEMENT: new Set(["loading", "idle", "selected", "editing_prop", "loading_doc"]),

  // Drag lifecycle
  DRAG_START: new Set(["selected"]),
  DRAG_MOVE: new Set(["dragging"]),
  DRAG_END: new Set(["dragging"]),

  // UI toggles always work
  TOGGLE_DOC_COLLAPSE: "*",
  TOGGLE_CAT_COLLAPSE: "*",
  TOGGLE_PHOTO_PANEL: "*",
  SET_PHOTO_SAVED_H: "*",
  TOGGLE_SHOW_NAMES: "*",
  TOGGLE_SHOW_BLEED: "*",
  TOGGLE_SNAP: "*",
  SET_ASSETS: "*",
};

export const guardMiddleware: Middleware = (state: AppState, event: AppEvent): AppEvent | null => {
  const rule = ALLOWED[event.type];
  if (rule === undefined) return event; // Unknown events pass through
  if (rule === "*") return event;
  if (rule.has(state.phase)) return event;
  return null;
};
