/**
 * alpine-bridge.ts — Alpine.data("illustrator") component
 *
 * Bridges Alpine.js reactivity with the Zustand store.
 * Alpine reads state via getters, Zustand subscribe forces Alpine updates.
 * Actions go through Zustand → supabase-sync → PG.
 */

// @ts-nocheck

import { store } from "./store.js";
import { findInElements } from "./helpers.js";
import { render } from "./render.js";
import { initZoom } from "./zoom.js";
import { undoManager } from "./history.js";
import * as sync from "./supabase-sync.js";

export interface IllustratorConfig {
  url: string;
  key: string;
  canvasId?: string;
}

let _config: IllustratorConfig;

export function registerAlpineComponent(Alpine: any, config: IllustratorConfig) {
  _config = config;

  Alpine.data("illustrator", () => ({
    // ---- Reactive getters from Zustand ----
    get canvas() { return store.getState().canvas; },
    get elements() { return store.getState().elements; },
    get selectedIds() { return store.getState().selectedIds; },
    get phase() { return store.getState().phase; },
    get zoom() { return store.getState().zoom; },
    get toast() { return store.getState().toast; },
    get snapEnabled() { return store.getState().snapEnabled; },
    get showNames() { return store.getState().showNames; },
    get showBleed() { return store.getState().showBleed; },
    get documentLocked() { return store.getState().documentLocked; },
    get layersPanelCollapsed() { return store.getState().layersPanelCollapsed; },
    get propsPanelCollapsed() { return store.getState().propsPanelCollapsed; },
    get photoCollapsed() { return store.getState().photoCollapsed; },
    get assets() { return store.getState().assets; },
    get docList() { return store.getState().docList; },

    get selectedElement() {
      const ids = store.getState().selectedIds;
      if (ids.length !== 1) return null;
      return findInElements(store.getState().elements, ids[0]);
    },

    get zoomPercent() {
      return Math.round(store.getState().zoom * 100) + "%";
    },

    // ---- Local Alpine state ----
    collapsedNodes: new Set(),
    docDropdownOpen: false,

    // ---- Init ----
    init() {
      const self = this;

      // Subscribe Zustand → force Alpine re-read on every state change
      store.subscribe(() => {
        self.$nextTick(() => {});
      });

      // Subscribe for D3 render
      store.subscribe(() => render());

      // Init zoom (D3 behavior on #canvasViewport)
      initZoom();

      // Init Supabase sync
      sync.init(_config.url, _config.key, _config.canvasId);
      sync.loadAssets();

      // Hide loader when canvas is loaded
      store.subscribe(() => {
        if (store.getState().canvas) {
          document.getElementById("loader")?.classList.add("hidden");
        }
      });

      // Keyboard shortcuts
      window.addEventListener("keydown", (e: KeyboardEvent) => this._onKeydown(e));
    },

    // ---- Actions ----
    selectElement(id: string, toggle?: boolean) {
      store.getState().selectElement(id, toggle);
    },

    clearSelection() {
      store.getState().clearSelection();
    },

    updateElement(id: string, props: object) {
      sync.updateElement(id, props);
    },

    deleteSelected() {
      for (const id of store.getState().selectedIds) {
        sync.deleteElement(id);
      }
      store.getState().clearSelection();
    },

    duplicateSelected() {
      const s = store.getState();
      for (const id of s.selectedIds) {
        const el = findInElements(s.elements, id);
        if (!el || !s.canvas) continue;
        const clone = { ...el, x: (el.x || 0) + 20, y: (el.y || 0) + 20 };
        delete clone.id;
        sync.addElement(s.canvas.id, clone.type, clone);
      }
    },

    undo() { undoManager.undo(); },
    redo() { undoManager.redo(); },

    toggleSnap() { store.getState().toggleSnap(); },
    toggleShowNames() { store.getState().toggleShowNames(); },
    toggleShowBleed() { store.getState().toggleShowBleed(); },
    toggleLock() { store.getState().toggleLock(); },
    toggleLayersPanel() { store.getState().toggleLayersPanel(); },
    togglePropsPanel() { store.getState().togglePropsPanel(); },
    togglePhotoPanel() { store.getState().togglePhotoPanel(); },

    toggleDocDropdown() {
      this.docDropdownOpen = !this.docDropdownOpen;
    },

    loadDoc(id: string) {
      this.docDropdownOpen = false;
      sync.destroy();
      _config.canvasId = id;
      sync.init(_config.url, _config.key, id);
    },

    setZoom(v: number) {
      store.getState().setZoom(v / 100);
    },

    // ---- Tree node collapse ----
    isCollapsed(id: string) {
      return this.collapsedNodes.has(id);
    },

    toggleNode(id: string) {
      if (this.collapsedNodes.has(id)) {
        this.collapsedNodes.delete(id);
      } else {
        this.collapsedNodes.add(id);
      }
    },

    // ---- Keyboard ----
    _onKeydown(e: KeyboardEvent) {
      const s = store.getState();
      const meta = e.metaKey || e.ctrlKey;
      const target = e.target as HTMLElement;
      if (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable) return;

      if (meta && e.key === "z" && !e.shiftKey) { e.preventDefault(); this.undo(); }
      if (meta && e.key === "z" && e.shiftKey) { e.preventDefault(); this.redo(); }
      if (e.key === "Backspace" || e.key === "Delete") { e.preventDefault(); this.deleteSelected(); }
      if (meta && e.key === "d") { e.preventDefault(); this.duplicateSelected(); }
      if (e.key === "Escape") { this.clearSelection(); }

      // Nudge
      const nudge = e.shiftKey ? 10 : 1;
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key) && s.selectedIds.length > 0) {
        e.preventDefault();
        const dx = e.key === "ArrowLeft" ? -nudge : e.key === "ArrowRight" ? nudge : 0;
        const dy = e.key === "ArrowUp" ? -nudge : e.key === "ArrowDown" ? nudge : 0;
        for (const id of s.selectedIds) {
          const el = findInElements(s.elements, id);
          if (!el) continue;
          if (el.type === "line") {
            sync.updateElement(id, { x1: el.x1 + dx, y1: el.y1 + dy, x2: el.x2 + dx, y2: el.y2 + dy });
          } else {
            sync.updateElement(id, { x: (el.x || 0) + dx, y: (el.y || 0) + dy });
          }
        }
      }
    },
  }));
}
