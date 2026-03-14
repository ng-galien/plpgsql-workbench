// ============================================================
// STORE — dispatch, subscribe, middleware
// ============================================================

import type { AppState } from "./types.js";
import type { AppEvent } from "./events.js";
import { rootReducer } from "./reducers.js";
import { pushLog } from "./logger.js";

export type Listener = (state: AppState, prevState: AppState, event: AppEvent) => void;
export type Middleware = (state: AppState, event: AppEvent) => AppEvent | null;

/** Extract a short detail string from an event for logging */
function eventDetail(event: AppEvent): string | undefined {
  switch (event.type) {
    case "SELECT_ELEMENT": return `${event.id ?? "null"}${event.toggle ? " +toggle" : ""}`;
    case "DRAG_START": return event.elId;
    case "PHASE_TRANSITION": return event.to;
    default: return undefined;
  }
}

const INITIAL_STATE: AppState = {
  doc: { currentDoc: null, docList: [] },
  ui: {
    selectedIds: [],
    layersPanelCollapsed: false,
    propsPanelCollapsed: false,
    photoCollapsed: true,
    photoSavedH: 130,
    showNames: true,
    showBleed: true,
    snapEnabled: true,
    documentLocked: false,
    assetsData: null,
  },
  ephemeral: { snapGuides: [], zoomLevel: 1 },
  refs: { ws: null, zoomBehavior: null, lastFitKey: null },
  phase: "loading",
};

class Store {
  private _state: AppState = INITIAL_STATE;
  private _listeners: Listener[] = [];
  private _middlewares: Middleware[] = [];

  get state(): AppState {
    return this._state;
  }

  dispatch(event: AppEvent): void {
    const phaseBefore = this._state.phase;

    for (const mw of this._middlewares) {
      const result = mw(this._state, event);
      if (result === null) {
        pushLog({ ts: Date.now(), type: event.type, phase: phaseBefore, blocked: true, detail: eventDetail(event) });
        return;
      }
      event = result;
    }

    const prev = this._state;
    this._state = rootReducer(prev, event);

    const phaseChanged = this._state.phase !== prev.phase;
    pushLog({
      ts: Date.now(),
      type: event.type,
      phase: phaseBefore,
      blocked: false,
      detail: phaseChanged ? `${phaseBefore}→${this._state.phase}` : eventDetail(event),
    });

    if (phaseChanged) {
      console.log(`[Store] Phase: ${prev.phase} -> ${this._state.phase} (${event.type})`);
    }

    if (this._state === prev) return; // Nothing changed

    for (const listener of this._listeners) {
      listener(this._state, prev, event);
    }
  }

  subscribe(listener: Listener): () => void {
    this._listeners.push(listener);
    return () => {
      const idx = this._listeners.indexOf(listener);
      if (idx >= 0) this._listeners.splice(idx, 1);
    };
  }

  use(middleware: Middleware): void {
    this._middlewares.push(middleware);
  }
}

export const store = new Store();
export const dispatch = store.dispatch.bind(store);
