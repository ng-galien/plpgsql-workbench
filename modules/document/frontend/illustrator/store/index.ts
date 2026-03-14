/**
 * Store bridge — maps the old store API to the new Zustand store.
 *
 * Drop-in replacement so render.ts, events.ts, props.ts, ui.ts, etc.
 * continue to work with zero changes to their imports.
 *
 * Old: import { store, dispatch } from "./store/index.js";
 *      store.state.doc.currentDoc
 *      dispatch({ type: "SELECT_ELEMENT", id })
 *
 * New: same imports, backed by Zustand.
 */

// @ts-nocheck

import { store as zustandStore, subscribe } from "../store.js";

/** Compatibility layer — mimics the old store.state shape */
export const store = {
  get state() {
    const s = zustandStore.getState();
    return {
      doc: {
        currentDoc: s.canvas ? {
          name: s.canvas.name,
          category: s.canvas.category,
          canvas: { format: s.canvas.format, orientation: s.canvas.orientation, w: s.canvas.w, h: s.canvas.h, bg: s.canvas.bg },
          meta: s.canvas.meta,
          elements: s.elements,
          nextId: s.elements.length + 1,
        } : null,
        docList: s.docList,
      },
      ui: {
        selectedIds: s.selectedIds,
        layersPanelCollapsed: s.layersPanelCollapsed,
        propsPanelCollapsed: s.propsPanelCollapsed,
        photoCollapsed: s.photoCollapsed,
        photoSavedH: 200,
        showNames: s.showNames,
        showBleed: s.showBleed,
        snapEnabled: s.snapEnabled,
        documentLocked: s.documentLocked,
        assetsData: s.assets.length > 0 ? { images: s.assets } : null,
      },
      ephemeral: {
        snapGuides: s.snapGuides,
        zoomLevel: s.zoom,
      },
      refs: {
        ws: null,
        zoomBehavior: s.zoomBehavior,
        lastFitKey: s.lastFitKey,
      },
      phase: s.phase,
    };
  },

  subscribe(fn) {
    let prev = store.state;
    return zustandStore.subscribe(() => {
      const next = store.state;
      fn(next, prev, {});
      prev = next;
    });
  },

  use(middleware) {
    // Guards middleware — no-op in Zustand bridge (guards are in dispatch)
  },
};

/** Compatibility dispatch — maps old event types to Zustand actions */
export function dispatch(event) {
  const s = zustandStore.getState();
  switch (event.type) {
    case "SELECT_ELEMENT":
      if (event.id === null) s.clearSelection();
      else s.selectElement(event.id, event.toggle);
      break;
    case "DRAG_START": s.setPhase("dragging"); break;
    case "DRAG_MOVE": s.setSnapGuides(event.snapGuides ?? []); break;
    case "DRAG_END": s.setPhase("selected"); s.setSnapGuides([]); break;
    case "SET_LAST_FIT_KEY": s.setLastFitKey(event.key); break;
    case "SET_ZOOM_LEVEL": s.setZoom(event.level); break;
    case "SET_ZOOM_BEHAVIOR": s.setZoomBehavior(event.behavior); break;
    case "SET_ASSETS": s.setAssets(event.assets?.images ?? event.assets ?? []); break;
    case "TOGGLE_SHOW_NAMES": s.toggleShowNames(); break;
    case "TOGGLE_SHOW_BLEED": s.toggleShowBleed(); break;
    case "TOGGLE_SNAP": s.toggleSnap(); break;
    case "TOGGLE_LOCK_DOC": s.toggleLock(); break;
    case "TOGGLE_PHOTO_PANEL": s.togglePhotoPanel(); break;
    case "TOGGLE_LAYERS_PANEL": s.toggleLayersPanel(); break;
    case "TOGGLE_PROPS_PANEL": s.togglePropsPanel(); break;
    case "PHASE_TRANSITION": s.setPhase(event.to); break;
    case "SET_PHOTO_SAVED_H": break; // ignored
    case "SET_WS": break; // no WS in Zustand mode
    case "SERVER_STATE":
      if (event.doc) {
        s.setCanvas({
          id: event.doc.id ?? "",
          name: event.doc.name,
          format: event.doc.canvas?.format ?? "A4",
          orientation: event.doc.canvas?.orientation ?? "portrait",
          w: event.doc.canvas?.w ?? 210,
          h: event.doc.canvas?.h ?? 297,
          bg: event.doc.canvas?.bg ?? "#ffffff",
          category: event.doc.category ?? "general",
          meta: event.doc.meta ?? {},
        });
        s.setElements(event.doc.elements ?? []);
      }
      if (event.docList) s.setDocList(event.docList);
      break;
    default:
      console.warn("Unknown dispatch:", event.type);
  }
}

/** subscribeToSlices compatibility */
export function subscribeToSlices(slices, fn) {
  const keys = [];
  for (const s of slices) {
    if (s === "doc") keys.push("canvas", "elements");
    if (s === "ui") keys.push("selectedIds", "showNames", "showBleed", "snapEnabled", "documentLocked");
    if (s === "ephemeral") keys.push("snapGuides", "zoom");
    if (s === "phase") keys.push("phase");
  }
  return subscribe(keys, fn);
}

/** Guards — no-op (handled in dispatch) */
export const guardMiddleware = (state, event) => event;

/** Selectors compatibility */
export function selectedElements() {
  const s = zustandStore.getState();
  return s.elements.filter(e => s.selectedIds.includes(e.id));
}

export function activeDocName() {
  return zustandStore.getState().canvas?.name ?? null;
}

export function getEventLog() { return []; }
