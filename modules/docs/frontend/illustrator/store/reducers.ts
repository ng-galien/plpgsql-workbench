// ============================================================
// STORE REDUCERS — pure functions (state, event) => state
// ============================================================

import type {
  AppState, DocumentSlice, UISlice, EphemeralSlice, RefsSlice, AppPhase,
} from "./types.js";
import type { AppEvent } from "./events.js";

function docReducer(slice: DocumentSlice, event: AppEvent): DocumentSlice {
  switch (event.type) {
    case "SERVER_STATE":
      // Skip if same doc reference (dedup)
      if (slice.currentDoc === event.doc && slice.docList === event.docList) return slice;
      return { currentDoc: event.doc, docList: event.docList };
    default:
      return slice;
  }
}

function uiReducer(slice: UISlice, event: AppEvent): UISlice {
  switch (event.type) {
    case "SELECT_ELEMENT": {
      if (event.id === null) {
        return slice.selectedIds.length === 0 ? slice : { ...slice, selectedIds: [] };
      }
      if (event.toggle) {
        const idx = slice.selectedIds.indexOf(event.id);
        const next = idx >= 0
          ? slice.selectedIds.filter(i => i !== event.id)
          : [...slice.selectedIds, event.id];
        return { ...slice, selectedIds: next };
      }
      if (slice.selectedIds.length === 1 && slice.selectedIds[0] === event.id) return slice;
      return { ...slice, selectedIds: [event.id] };
    }
    case "TOGGLE_LAYERS_PANEL":
      return { ...slice, layersPanelCollapsed: !slice.layersPanelCollapsed };
    case "TOGGLE_PROPS_PANEL":
      return { ...slice, propsPanelCollapsed: !slice.propsPanelCollapsed };
    case "TOGGLE_PHOTO_PANEL":
      return { ...slice, photoCollapsed: !slice.photoCollapsed };
    case "SET_PHOTO_SAVED_H":
      return { ...slice, photoSavedH: event.height };
    case "TOGGLE_SHOW_NAMES":
      return { ...slice, showNames: !slice.showNames };
    case "TOGGLE_SHOW_BLEED":
      return { ...slice, showBleed: !slice.showBleed };
    case "TOGGLE_SNAP":
      return { ...slice, snapEnabled: !slice.snapEnabled };
    case "TOGGLE_LOCK_DOC":
      return { ...slice, documentLocked: !slice.documentLocked };
    case "SET_ASSETS":
      return { ...slice, assetsData: event.assets };
    default:
      return slice;
  }
}

function ephemeralReducer(slice: EphemeralSlice, event: AppEvent): EphemeralSlice {
  switch (event.type) {
    case "DRAG_START":
      return { ...slice, snapGuides: [] };
    case "DRAG_MOVE":
      return { ...slice, snapGuides: event.snapGuides };
    case "DRAG_END":
      if (slice.snapGuides.length === 0) return slice;
      return { ...slice, snapGuides: [] };
    case "SET_ZOOM_LEVEL":
      return { ...slice, zoomLevel: event.level };
    default:
      return slice;
  }
}

function refsReducer(slice: RefsSlice, event: AppEvent): RefsSlice {
  switch (event.type) {
    case "SET_WS":
      return { ...slice, ws: event.ws };
    case "SET_ZOOM_BEHAVIOR":
      return { ...slice, zoomBehavior: event.behavior };
    case "SET_LAST_FIT_KEY":
      return { ...slice, lastFitKey: event.key };
    default:
      return slice;
  }
}

function phaseReducer(phase: AppPhase, event: AppEvent, ui: UISlice): AppPhase {
  switch (event.type) {
    case "PHASE_TRANSITION":
      return event.to;
    case "SERVER_STATE":
      if (event.doc && (phase === "loading" || phase === "loading_doc")) {
        return ui.selectedIds.length > 0 ? "selected" : "idle";
      }
      if (!event.doc) return "loading";
      return phase;
    case "SELECT_ELEMENT":
      if (phase === "dragging") return phase; // guard: no phase change during drag
      return ui.selectedIds.length > 0 ? "selected" : "idle";
    case "DRAG_START":
      return "dragging";
    case "DRAG_END":
      return "selected";
    default:
      return phase;
  }
}

export function rootReducer(state: AppState, event: AppEvent): AppState {
  const doc = docReducer(state.doc, event);
  const ui = uiReducer(state.ui, event);
  const ephemeral = ephemeralReducer(state.ephemeral, event);
  const refs = refsReducer(state.refs, event);
  const phase = phaseReducer(state.phase, event, ui);

  // Return same reference if nothing changed (enables === checks in subscribers)
  if (
    doc === state.doc &&
    ui === state.ui &&
    ephemeral === state.ephemeral &&
    refs === state.refs &&
    phase === state.phase
  ) {
    return state;
  }

  return { doc, ui, ephemeral, refs, phase };
}
