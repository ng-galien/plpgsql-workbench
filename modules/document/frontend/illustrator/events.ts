// ============================================================
// EVENTS — DOM event bindings, resize handlers
// ============================================================

import "./styles/layout.css";

import { store, dispatch, selectedElements } from "./store/index.js";
import { fitSVG } from "./zoom.js";
import { hideMeta, uploadFile } from "./photos.js";
import { sendUpdate, sendDelete, sendSave, sendAddElement, setSelection, onNextStateUpdate, wsSend } from "./ws.js";
import { undoManager } from "./history.js";
import { copySelected, pasteClipboard, duplicateSelected } from "./clipboard.js";
import { showToast } from "./toast.js";

/** Delete all selected elements with undo support */
function deleteSelectedWithUndo(): void {
  const els = selectedElements(store.state);
  if (els.length === 0) return;

  const entries = els.map(el => {
    const saved = structuredClone(el) as any;
    delete saved.href;
    return { saved, currentId: el.id };
  });

  undoManager.push({
    label: `Delete ${entries.length} element(s)`,
    undo: () => {
      for (const e of entries) {
        sendAddElement(e.saved);
        onNextStateUpdate(() => {
          const doc = store.state.doc.currentDoc;
          if (!doc) return;
          const last = doc.elements[doc.elements.length - 1];
          if (last) e.currentId = last.id;
        });
      }
    },
    redo: () => { for (const e of entries) sendDelete(e.currentId); },
  });

  for (const e of entries) sendDelete(e.currentId);
  setSelection(null);
}

/** Reusable panel resize handler */
function initPanelResize(handleId: string, cssVar: string, min: number, max: number): void {
  const handle = document.getElementById(handleId);
  if (!handle) return;

  handle.addEventListener('mousedown', (e) => {
    // Block resize when panel is collapsed
    const isLayers = cssVar === '--layers-w';
    const panel = document.getElementById(isLayers ? 'layersPanel' : 'propsPanel');
    if (panel?.classList.contains('collapsed')) return;
    e.preventDefault();
    handle.classList.add('active');
    document.body.style.cursor = 'col-resize';
    const workspace = document.getElementById('workspace')!;

    const onMove = (ev: MouseEvent) => {
      const rect = workspace.getBoundingClientRect();
      let w: number;
      if (cssVar === '--layers-w') {
        w = ev.clientX - rect.left;
      } else {
        w = rect.right - ev.clientX;
      }
      w = Math.min(Math.max(w, min), max);
      workspace.style.setProperty(cssVar, w + 'px');
    };
    const onUp = () => {
      handle.classList.remove('active');
      document.body.style.cursor = '';
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
      fitSVG();
    };
    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  });
}

export function initEvents(): void {
  // ---- Panel resize ----
  initPanelResize('resizeHandleL', '--layers-w', 140, 400);
  initPanelResize('resizeHandleR', '--props-w', 160, 400);

  // ---- Photo library resize ----
  const photoPanel = document.getElementById('photoPanel') as HTMLElement;
  const resizeHandleH = document.getElementById('resizeHandleH') as HTMLElement;
  if (resizeHandleH && photoPanel) {
    resizeHandleH.addEventListener('mousedown', (e) => {
      if (photoPanel.classList.contains('collapsed')) return;
      e.preventDefault();
      resizeHandleH.classList.add('active');
      document.body.style.cursor = 'row-resize';
      const onMove = (ev: MouseEvent) => {
        const bodyH = document.body.getBoundingClientRect().height;
        const bottomY = document.body.getBoundingClientRect().bottom;
        const h = Math.min(Math.max(bottomY - ev.clientY, 40), bodyH * 0.4);
        photoPanel.style.height = h + 'px';
      };
      const onUp = () => {
        resizeHandleH.classList.remove('active');
        document.body.style.cursor = '';
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        dispatch({ type: "SET_PHOTO_SAVED_H", height: photoPanel.offsetHeight });
        fitSVG();
      };
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // ---- Photo library collapse ----
  document.getElementById('collapsePhotoBtn')?.addEventListener('click', () => {
    dispatch({ type: "TOGGLE_PHOTO_PANEL" });
    const collapsed = store.state.ui.photoCollapsed;
    photoPanel?.classList.toggle('collapsed', collapsed);
    resizeHandleH?.classList.toggle('disabled', collapsed);
    if (!collapsed && photoPanel) {
      photoPanel.style.height = store.state.ui.photoSavedH + 'px';
    }
    fitSVG();
  });
  // Apply initial collapsed state
  if (store.state.ui.photoCollapsed) {
    photoPanel?.classList.add('collapsed');
    resizeHandleH?.classList.add('disabled');
  }

  // ---- Panel collapse buttons ----
  const workspace = document.getElementById('workspace')!;
  document.getElementById('collapseLayersBtn')?.addEventListener('click', () => {
    dispatch({ type: "TOGGLE_LAYERS_PANEL" });
    const collapsed = store.state.ui.layersPanelCollapsed;
    document.getElementById('layersPanel')?.classList.toggle('collapsed', collapsed);
    workspace.style.setProperty('--layers-w', collapsed ? '28px' : '200px');
    fitSVG();
  });
  document.getElementById('collapsePropsBtn')?.addEventListener('click', () => {
    dispatch({ type: "TOGGLE_PROPS_PANEL" });
    const collapsed = store.state.ui.propsPanelCollapsed;
    document.getElementById('propsPanel')?.classList.toggle('collapsed', collapsed);
    workspace.style.setProperty('--props-w', collapsed ? '28px' : '220px');
    fitSVG();
  });

  // ---- Doc selector dropdown ----
  const docSelector = document.getElementById('docSelector');
  const docDropdown = document.getElementById('docDropdown');
  if (docSelector && docDropdown) {
    docSelector.addEventListener('click', (e) => {
      e.stopPropagation();
      const isOpen = docSelector.classList.toggle('open');
      docDropdown.classList.toggle('open', isOpen);
    });
    // Close on click outside
    document.addEventListener('click', (e) => {
      if (!docSelector.contains(e.target as Node) && !docDropdown.contains(e.target as Node)) {
        docSelector.classList.remove('open');
        docDropdown.classList.remove('open');
      }
    });
  }

  // ---- Menu bar buttons ----
  document.getElementById('btnUndo')?.addEventListener('click', () => undoManager.undo());
  document.getElementById('btnRedo')?.addEventListener('click', () => undoManager.redo());
  document.getElementById('btnSave')?.addEventListener('click', () => { sendSave(); showToast('Sauvegarde', 'success'); });

  // ---- Toggle buttons ----
  const wireToggle = (id: string, eventType: any, stateKey: keyof typeof store.state.ui) => {
    const btn = document.getElementById(id)!;
    btn.addEventListener('click', () => {
      dispatch({ type: eventType });
      btn.classList.toggle('active', store.state.ui[stateKey] as boolean);
    });
  };
  wireToggle('toggleNames', 'TOGGLE_SHOW_NAMES', 'showNames');
  wireToggle('toggleBleed', 'TOGGLE_SHOW_BLEED', 'showBleed');
  wireToggle('toggleSnap', 'TOGGLE_SNAP', 'snapEnabled');

  const toggleLock = document.getElementById('toggleLock')!;
  toggleLock.addEventListener('click', () => {
    dispatch({ type: "TOGGLE_LOCK_DOC" });
    const locked = store.state.ui.documentLocked;
    toggleLock.classList.toggle('active', locked);
    document.querySelector('.canvas-viewport')?.classList.toggle('locked', locked);
  });

  // ---- Zoom slider ----
  const zoomSlider = document.getElementById('zoomSlider') as HTMLInputElement;
  if (zoomSlider) {
    zoomSlider.addEventListener('input', () => {
      const level = parseInt(zoomSlider.value) / 100;
      const zoomBehavior = store.state.refs.zoomBehavior;
      if (!zoomBehavior) return;
      const viewport = d3.select('.canvas-viewport');
      viewport.call(zoomBehavior.scaleTo, level);
    });
  }

  // ---- Layers action buttons ----
  document.getElementById('actionDelete')?.addEventListener('click', deleteSelectedWithUndo);

  document.getElementById('actionDuplicate')?.addEventListener('click', () => {
    duplicateSelected();
  });

  document.getElementById('actionMoveUp')?.addEventListener('click', () => {
    const els = selectedElements(store.state);
    for (const el of els) wsSend({ type: 'reorder_element', id: el.id, action: 'forward' });
  });

  document.getElementById('actionMoveDown')?.addEventListener('click', () => {
    const els = selectedElements(store.state);
    for (const el of els) wsSend({ type: 'reorder_element', id: el.id, action: 'backward' });
  });

  // ---- Meta overlay ----
  document.getElementById('metaClose')?.addEventListener('click', hideMeta);
  document.getElementById('metaOverlay')?.addEventListener('click', (e) => { if (e.target === e.currentTarget) hideMeta(); });

  // ---- Upload zone ----
  const uploadZone = document.getElementById('uploadZone') as HTMLElement;
  const uploadInput = document.getElementById('uploadInput') as HTMLInputElement;
  if (uploadZone && uploadInput) {
    uploadZone.addEventListener('click', () => uploadInput.click());
    uploadZone.addEventListener('dragover', (e) => { e.preventDefault(); uploadZone.classList.add('dragover'); });
    uploadZone.addEventListener('dragleave', () => uploadZone.classList.remove('dragover'));
    uploadZone.addEventListener('drop', (e) => {
      e.preventDefault();
      uploadZone.classList.remove('dragover');
      for (const file of e.dataTransfer!.files) {
        if (file.type.startsWith('image/')) uploadFile(file);
      }
    });
    uploadInput.addEventListener('change', () => {
      for (const file of uploadInput.files!) uploadFile(file);
      uploadInput.value = '';
    });
  }

  // ---- Unified keyboard handler ----
  document.addEventListener('keydown', (e: KeyboardEvent) => {
    // Escape: works everywhere — dismiss meta overlay + deselect
    if (e.key === 'Escape') {
      hideMeta();
      // Close doc dropdown
      document.getElementById('docSelector')?.classList.remove('open');
      document.getElementById('docDropdown')?.classList.remove('open');
      if (store.state.ui.selectedIds.length > 0) {
        setSelection(null);
        document.querySelectorAll('.selection-rect').forEach(n => n.remove());
      }
      return;
    }

    // Guard: skip shortcuts when typing in inputs
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (e.target as HTMLElement).isContentEditable) return;

    // Guard: block shortcuts during drag
    if (store.state.phase === "dragging") return;

    // Space: toggle document lock (delegate to button click)
    if (e.key === ' ') {
      e.preventDefault();
      document.getElementById('toggleLock')?.click();
      return;
    }

    const mod = e.metaKey || e.ctrlKey;

    // Undo: Ctrl/Cmd+Z
    if (mod && e.key === 'z' && !e.shiftKey) { e.preventDefault(); undoManager.undo(); return; }
    // Redo: Ctrl/Cmd+Y or Ctrl/Cmd+Shift+Z
    if ((mod && e.key === 'y') || (mod && e.key === 'z' && e.shiftKey)) { e.preventDefault(); undoManager.redo(); return; }
    // Save: Ctrl/Cmd+S
    if (mod && e.key === 's') { e.preventDefault(); sendSave(); showToast('Sauvegarde', 'success'); return; }
    // Copy: Ctrl/Cmd+C
    if (mod && e.key === 'c') { e.preventDefault(); copySelected(); return; }
    // Paste: Ctrl/Cmd+V
    if (mod && e.key === 'v') { e.preventDefault(); pasteClipboard(); return; }
    // Duplicate: Ctrl/Cmd+D
    if (mod && e.key === 'd') { e.preventDefault(); duplicateSelected(); return; }

    // Delete: Delete or Backspace
    if (e.key === 'Delete' || e.key === 'Backspace') {
      e.preventDefault();
      deleteSelectedWithUndo();
      return;
    }

    // Nudge: Arrow keys ±1mm, Shift ±5mm
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {
      e.preventDefault();
      const els = selectedElements(store.state);
      if (els.length === 0) return;
      const step = e.shiftKey ? 5 : 1;
      const dx = e.key === 'ArrowRight' ? step : e.key === 'ArrowLeft' ? -step : 0;
      const dy = e.key === 'ArrowDown' ? step : e.key === 'ArrowUp' ? -step : 0;
      const mergeId = `nudge:${els.map(e => e.id).join(',')}`;

      const entries: Array<{ id: string; oldProps: any; newProps: any }> = [];
      for (const el of els) {
        if (el.type === 'group') continue;
        if (el.type === 'line') {
          const oldProps = { x1: el.x1, y1: el.y1, x2: el.x2, y2: el.y2 };
          const newProps = { x1: el.x1 + dx, y1: el.y1 + dy, x2: el.x2 + dx, y2: el.y2 + dy };
          entries.push({ id: el.id, oldProps, newProps });
        } else {
          const oldProps = { x: el.x, y: el.y };
          const newProps = { x: el.x + dx, y: el.y + dy };
          entries.push({ id: el.id, oldProps, newProps });
        }
      }
      if (entries.length > 0) {
        undoManager.push({
          label: `Nudge ${entries.length} element(s)`,
          mergeId,
          undo: () => { for (const e of entries) sendUpdate(e.id, e.oldProps); },
          redo: () => { for (const e of entries) sendUpdate(e.id, e.newProps); },
        });
        for (const e of entries) sendUpdate(e.id, e.newProps);
      }
      return;
    }
  });

  // Window resize
  window.addEventListener('resize', () => fitSVG());
}
