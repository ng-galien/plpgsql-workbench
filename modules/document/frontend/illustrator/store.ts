/**
 * Zustand vanilla store — replaces store/ directory (7 files → 1 file).
 *
 * State shape preserves the original slices for compatibility with render.ts,
 * events.ts, props.ts, etc. Migration path: store.state.X → store.getState().X
 *
 * Sync:
 *   - Persistent data (canvas, elements) ← Supabase Realtime Postgres Changes
 *   - Ephemeral state (selection, phase) → PG UNLOGGED session table
 *   - Local-only (zoom, snap guides, refs) → never leaves the browser
 */

// @ts-nocheck — this file runs in the browser with global d3, zustand, supabase

/** ---- Types ---- */

interface Canvas {
  id: string;
  name: string;
  format: string;
  orientation: string;
  w: number;
  h: number;
  bg: string;
  category: string;
  meta: Record<string, unknown>;
}

interface Element {
  id: string;
  type: string;
  name?: string;
  parent_id?: string;
  sort_order: number;
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  x1?: number;
  y1?: number;
  x2?: number;
  y2?: number;
  cx?: number;
  cy?: number;
  r?: number;
  opacity: number;
  rotation: number;
  fill?: string;
  stroke?: string;
  stroke_width?: number;
  props: Record<string, unknown>;
  asset_id?: string;
  children?: Element[];
}

interface Guide {
  axis: "h" | "v";
  pos: number;
}

interface AssetImage {
  id: string;
  filename: string;
  path: string;
  thumb_path?: string;
  title?: string;
  description?: string;
  tags?: string[];
  status: string;
}

type AppPhase = "loading" | "idle" | "selected" | "dragging" | "editing_prop" | "loading_doc";

interface IllustratorState {
  // ---- Persistent (synced from PG via Realtime) ----
  canvas: Canvas | null;
  elements: Element[];
  docList: { id: string; name: string; category: string; format: string }[];

  // ---- Ephemeral (synced to PG UNLOGGED session) ----
  selectedIds: string[];
  phase: AppPhase;

  // ---- Local only ----
  zoom: number;
  snapGuides: Guide[];
  snapEnabled: boolean;
  showNames: boolean;
  showBleed: boolean;
  documentLocked: boolean;
  photoCollapsed: boolean;
  layersPanelCollapsed: boolean;
  propsPanelCollapsed: boolean;
  assets: AssetImage[];
  toast: { text: string; level: string; duration: number } | null;

  // ---- Refs (non-serializable) ----
  zoomBehavior: any;
  lastFitKey: string | null;

  // ---- Actions ----
  setCanvas: (c: Canvas | null) => void;
  setElements: (els: Element[]) => void;
  setDocList: (list: any[]) => void;

  addElement: (el: Element) => void;
  updateElement: (id: string, props: Partial<Element>) => void;
  removeElement: (id: string) => void;

  selectElement: (id: string, toggle?: boolean) => void;
  clearSelection: () => void;
  setPhase: (p: AppPhase) => void;

  setZoom: (z: number) => void;
  setSnapGuides: (guides: Guide[]) => void;
  toggleSnap: () => void;
  toggleShowNames: () => void;
  toggleShowBleed: () => void;
  toggleLock: () => void;
  togglePhotoPanel: () => void;
  toggleLayersPanel: () => void;
  togglePropsPanel: () => void;

  setAssets: (a: AssetImage[]) => void;
  showToast: (text: string, level?: string, duration?: number) => void;
  clearToast: () => void;

  setZoomBehavior: (zb: any) => void;
  setLastFitKey: (k: string | null) => void;
}

/** ---- Store ---- */

// zustand is loaded as UMD global from CDN
const createStore = (window as any).zustand?.createStore ?? (window as any).zustandVanilla?.createStore;

export const store = createStore<IllustratorState>((set: any, get: any) => ({
  // ---- Initial state ----
  canvas: null,
  elements: [],
  docList: [],

  selectedIds: [],
  phase: "loading" as AppPhase,

  zoom: 1,
  snapGuides: [],
  snapEnabled: true,
  showNames: true,
  showBleed: true,
  documentLocked: false,
  photoCollapsed: true,
  layersPanelCollapsed: false,
  propsPanelCollapsed: false,
  assets: [],
  toast: null,

  zoomBehavior: null,
  lastFitKey: null,

  // ---- Actions ----
  setCanvas: (c: Canvas | null) => set({ canvas: c, phase: c ? "idle" : "loading" }),
  setElements: (els: Element[]) => set({ elements: els }),
  setDocList: (list: any[]) => set({ docList: list }),

  addElement: (el: Element) => set((s: IllustratorState) => ({
    elements: [...s.elements, el],
  })),
  updateElement: (id: string, props: Partial<Element>) => set((s: IllustratorState) => ({
    elements: s.elements.map(e => e.id === id ? { ...e, ...props } : e),
  })),
  removeElement: (id: string) => set((s: IllustratorState) => ({
    elements: s.elements.filter(e => e.id !== id),
    selectedIds: s.selectedIds.filter(sid => sid !== id),
  })),

  selectElement: (id: string, toggle?: boolean) => set((s: IllustratorState) => {
    if (toggle) {
      const has = s.selectedIds.includes(id);
      const ids = has ? s.selectedIds.filter(x => x !== id) : [...s.selectedIds, id];
      return { selectedIds: ids, phase: ids.length > 0 ? "selected" : "idle" };
    }
    return { selectedIds: [id], phase: "selected" };
  }),
  clearSelection: () => set({ selectedIds: [], phase: "idle" }),
  setPhase: (p: AppPhase) => set({ phase: p }),

  setZoom: (z: number) => set({ zoom: z }),
  setSnapGuides: (guides: Guide[]) => set({ snapGuides: guides }),
  toggleSnap: () => set((s: IllustratorState) => ({ snapEnabled: !s.snapEnabled })),
  toggleShowNames: () => set((s: IllustratorState) => ({ showNames: !s.showNames })),
  toggleShowBleed: () => set((s: IllustratorState) => ({ showBleed: !s.showBleed })),
  toggleLock: () => set((s: IllustratorState) => ({ documentLocked: !s.documentLocked })),
  togglePhotoPanel: () => set((s: IllustratorState) => ({ photoCollapsed: !s.photoCollapsed })),
  toggleLayersPanel: () => set((s: IllustratorState) => ({ layersPanelCollapsed: !s.layersPanelCollapsed })),
  togglePropsPanel: () => set((s: IllustratorState) => ({ propsPanelCollapsed: !s.propsPanelCollapsed })),

  setAssets: (a: AssetImage[]) => set({ assets: a }),
  showToast: (text: string, level = "info", duration = 3000) => {
    set({ toast: { text, level, duration } });
    setTimeout(() => get().clearToast(), duration);
  },
  clearToast: () => set({ toast: null }),

  setZoomBehavior: (zb: any) => set({ zoomBehavior: zb }),
  setLastFitKey: (k: string | null) => set({ lastFitKey: k }),
}));

/** Subscribe helper — re-render when specific keys change */
export function subscribe(keys: (keyof IllustratorState)[], fn: () => void): () => void {
  let prev = keys.map(k => store.getState()[k]);
  return store.subscribe(() => {
    const curr = keys.map(k => store.getState()[k]);
    if (keys.some((_, i) => curr[i] !== prev[i])) {
      prev = curr;
      fn();
    }
  });
}
