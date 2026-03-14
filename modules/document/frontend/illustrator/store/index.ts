// ============================================================
// STORE — barrel re-export
// ============================================================

export { store, dispatch } from "./store.js";
export type { Listener, Middleware } from "./store.js";
export type { AppState, AppPhase, DocumentSlice, UISlice, EphemeralSlice, RefsSlice } from "./types.js";
export type { AppEvent, DocEvent, UIEvent, EphemeralEvent, RefEvent, PhaseEvent } from "./events.js";
export { rootReducer } from "./reducers.js";
export { guardMiddleware } from "./guards.js";
export { subscribeToSlices, subscribeToSelector } from "./subscribe.js";
export { selectedElements, activeDocName } from "./selectors.js";
export { getEventLog } from "./logger.js";
export type { LogEntry } from "./logger.js";
