// ============================================================
// IMAGE EDITOR — modal for crop, fit, flip, filters
// ============================================================

import "./styles/image-editor.css";

import { store } from "./store/index.js";
import { sendUpdate } from "./ws.js";
import { undoManager } from "./history.js";
import { findInElements } from "./helpers.js";
import type { ImageElement } from "./types.js";

let currentElId: string | null = null;
let snapshot: Record<string, any> | null = null;

// Working copy of editable properties
let draft = {
  objectFit: 'cover' as 'cover' | 'contain' | 'fill',
  cropX: 0.5,
  cropY: 0.5,
  cropZoom: 1,
  flipH: false,
  flipV: false,
  brightness: 100,
  contrast: 100,
  grayscale: 0,
};

// Preview state
let previewImg: HTMLImageElement | null = null;
let frameW = 0, frameH = 0;
let natW = 0, natH = 0;
let isDragging = false;
let dragStartX = 0, dragStartY = 0;
let dragStartCropX = 0, dragStartCropY = 0;
let cleanupListeners: (() => void) | null = null;

function getOverlay(): HTMLElement {
  return document.getElementById('imageEditorOverlay')!;
}

export function openImageEditor(elId: string): void {
  const doc = store.state.doc.currentDoc;
  if (!doc) return;
  const el = findInElements(doc.elements, elId) as ImageElement | null;
  if (!el || el.type !== 'image') return;

  currentElId = elId;

  // Snapshot for undo (with defaults for legacy documents)
  snapshot = {
    objectFit: el.objectFit || 'cover',
    cropX: el.cropX ?? 0.5, cropY: el.cropY ?? 0.5, cropZoom: el.cropZoom ?? 1,
    flipH: el.flipH ?? false, flipV: el.flipV ?? false,
    brightness: el.brightness ?? 100, contrast: el.contrast ?? 100, grayscale: el.grayscale ?? 0,
  };

  // Init draft from element
  draft = { ...snapshot } as typeof draft;

  natW = el.naturalWidth || el.width;
  natH = el.naturalHeight || el.height;
  frameW = el.width;
  frameH = el.height;

  const overlay = getOverlay();
  overlay.classList.add('visible');

  // Header
  const pathSpan = overlay.querySelector('.ie-header-path') as HTMLElement;
  if (pathSpan) pathSpan.textContent = el.path || '';

  // Build preview
  buildPreview(el.href);

  // Build controls
  buildControls();

  updatePreview();
}

export function closeImageEditor(apply = false): void {
  const overlay = getOverlay();
  overlay.classList.remove('visible');

  // Clean up document-level listeners
  if (cleanupListeners) { cleanupListeners(); cleanupListeners = null; }
  previewImg = null;

  if (apply && currentElId && snapshot) {
    const oldProps = { ...snapshot };
    const newProps = { ...draft };
    sendUpdate(currentElId, newProps);
    const elId = currentElId;
    undoManager.push({
      label: `Edit image ${elId}`,
      undo: () => sendUpdate(elId, oldProps),
      redo: () => sendUpdate(elId, newProps),
    });
  }

  currentElId = null;
  snapshot = null;
}

function buildPreview(href: string | null): void {
  const container = document.getElementById('iePreview')!;
  container.innerHTML = '';

  // Calculate preview scale (fit the frame within the preview area)
  const maxPreviewW = 480, maxPreviewH = 380;
  const scale = Math.min(maxPreviewW / frameW, maxPreviewH / frameH, 3);
  const pxW = frameW * scale, pxH = frameH * scale;

  const frame = document.createElement('div');
  frame.className = 'ie-preview-frame';
  frame.style.width = pxW + 'px';
  frame.style.height = pxH + 'px';

  const img = document.createElement('img');
  img.src = href || '';
  previewImg = img;
  frame.appendChild(img);
  container.appendChild(frame);

  // Hint
  const hint = document.createElement('div');
  hint.className = 'ie-preview-hint';
  hint.textContent = 'Glisser pour recadrer \u00b7 Molette pour zoomer';
  container.appendChild(hint);

  // Drag pan
  frame.addEventListener('mousedown', (e) => {
    if (draft.objectFit !== 'cover') return;
    isDragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;
    dragStartCropX = draft.cropX;
    dragStartCropY = draft.cropY;
    e.preventDefault();
  });

  const onMove = (e: MouseEvent) => {
    if (!isDragging || !previewImg) return;
    const dxPx = e.clientX - dragStartX;
    const dyPx = e.clientY - dragStartY;

    // Convert pixel drag to crop delta (0-1)
    const zoom = draft.cropZoom || 1;
    const baseScale = Math.max(frameW / natW, frameH / natH);
    const imgScale = baseScale * zoom;
    const excessW = natW * imgScale - frameW;
    const excessH = natH * imgScale - frameH;

    const previewScale = parseFloat(frame.style.width) / frameW;
    const dcx = excessW > 0 ? -(dxPx / previewScale) / excessW : 0;
    const dcy = excessH > 0 ? -(dyPx / previewScale) / excessH : 0;

    draft.cropX = Math.max(0, Math.min(1, dragStartCropX + dcx));
    draft.cropY = Math.max(0, Math.min(1, dragStartCropY + dcy));
    updatePreview();
  };

  const onUp = () => { isDragging = false; };
  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  cleanupListeners = () => {
    document.removeEventListener('mousemove', onMove);
    document.removeEventListener('mouseup', onUp);
  };

  // Wheel zoom
  frame.addEventListener('wheel', (e) => {
    if (draft.objectFit !== 'cover') return;
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.05 : 0.05;
    draft.cropZoom = Math.max(1, Math.min(5, draft.cropZoom + delta));
    updatePreview();
    // Update zoom slider
    const zoomSlider = document.getElementById('ieZoom') as HTMLInputElement;
    const zoomVal = document.getElementById('ieZoomVal') as HTMLElement;
    if (zoomSlider) zoomSlider.value = String(draft.cropZoom);
    if (zoomVal) zoomVal.textContent = draft.cropZoom.toFixed(1);
  }, { passive: false });
}

function updatePreview(): void {
  if (!previewImg) return;
  const frame = previewImg.parentElement!;
  const pxW = parseFloat(frame.style.width);
  const pxH = parseFloat(frame.style.height);
  const scaleRatio = pxW / frameW; // preview pixels per mm

  if (draft.objectFit === 'cover') {
    const zoom = draft.cropZoom || 1;
    const baseScale = Math.max(frameW / natW, frameH / natH);
    const imgScale = baseScale * zoom;
    const imgW = natW * imgScale * scaleRatio;
    const imgH = natH * imgScale * scaleRatio;
    const imgX = -(imgW - pxW) * draft.cropX;
    const imgY = -(imgH - pxH) * draft.cropY;

    previewImg.style.width = imgW + 'px';
    previewImg.style.height = imgH + 'px';
    previewImg.style.left = imgX + 'px';
    previewImg.style.top = imgY + 'px';
  } else if (draft.objectFit === 'contain') {
    const fitScale = Math.min(pxW / natW, pxH / natH);
    const w = natW * fitScale, h = natH * fitScale;
    previewImg.style.width = w + 'px';
    previewImg.style.height = h + 'px';
    previewImg.style.left = (pxW - w) / 2 + 'px';
    previewImg.style.top = (pxH - h) / 2 + 'px';
  } else {
    // fill
    previewImg.style.width = pxW + 'px';
    previewImg.style.height = pxH + 'px';
    previewImg.style.left = '0px';
    previewImg.style.top = '0px';
  }

  // Flip
  const sx = draft.flipH ? -1 : 1, sy = draft.flipV ? -1 : 1;
  previewImg.style.transform = `scale(${sx}, ${sy})`;

  // Filters
  const filters: string[] = [];
  if (draft.brightness !== 100) filters.push(`brightness(${draft.brightness}%)`);
  if (draft.contrast !== 100) filters.push(`contrast(${draft.contrast}%)`);
  if (draft.grayscale > 0) filters.push(`grayscale(${draft.grayscale}%)`);
  previewImg.style.filter = filters.join(' ');
}

function buildControls(): void {
  const panel = document.getElementById('ieControls')!;
  panel.innerHTML = '';

  // --- Object-fit ---
  const fitSection = sec('Cadrage');
  const fitGroup = document.createElement('div');
  fitGroup.className = 'ie-fit-group';
  for (const mode of ['cover', 'contain', 'fill'] as const) {
    const btn = document.createElement('button');
    btn.className = 'ie-fit-btn' + (draft.objectFit === mode ? ' active' : '');
    btn.textContent = mode === 'cover' ? 'Couvrir' : mode === 'contain' ? 'Contenir' : 'Etirer';
    btn.addEventListener('click', () => {
      draft.objectFit = mode;
      fitGroup.querySelectorAll('.ie-fit-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      updatePreview();
    });
    fitGroup.appendChild(btn);
  }
  fitSection.appendChild(fitGroup);
  panel.appendChild(fitSection);

  // --- Zoom slider ---
  const zoomSection = sec('Zoom');
  zoomSection.appendChild(slider('Zoom', 'ieZoom', 1, 5, 0.1, draft.cropZoom, (v) => {
    draft.cropZoom = v;
    updatePreview();
  }));
  panel.appendChild(zoomSection);

  // --- Flip ---
  const flipSection = sec('Retournement');
  const flipGroup = document.createElement('div');
  flipGroup.className = 'ie-flip-group';
  const flipH = document.createElement('button');
  flipH.className = 'ie-flip-btn' + (draft.flipH ? ' active' : '');
  flipH.textContent = '\u2194 H';
  flipH.addEventListener('click', () => { draft.flipH = !draft.flipH; flipH.classList.toggle('active'); updatePreview(); });
  const flipV = document.createElement('button');
  flipV.className = 'ie-flip-btn' + (draft.flipV ? ' active' : '');
  flipV.textContent = '\u2195 V';
  flipV.addEventListener('click', () => { draft.flipV = !draft.flipV; flipV.classList.toggle('active'); updatePreview(); });
  flipGroup.append(flipH, flipV);
  flipSection.appendChild(flipGroup);
  panel.appendChild(flipSection);

  // --- Filters ---
  const filterSection = sec('Filtres');
  filterSection.appendChild(slider('Lum', 'ieBrightness', 50, 150, 1, draft.brightness, (v) => { draft.brightness = v; updatePreview(); }));
  filterSection.appendChild(slider('Ctr', 'ieContrast', 50, 150, 1, draft.contrast, (v) => { draft.contrast = v; updatePreview(); }));
  filterSection.appendChild(slider('N&B', 'ieGrayscale', 0, 100, 1, draft.grayscale, (v) => { draft.grayscale = v; updatePreview(); }));
  panel.appendChild(filterSection);

  // --- Reset button ---
  const resetSection = document.createElement('div');
  resetSection.className = 'ie-section';
  const resetBtn = document.createElement('button');
  resetBtn.className = 'ie-btn';
  resetBtn.style.width = '100%';
  resetBtn.textContent = 'Reinitialiser';
  resetBtn.addEventListener('click', () => {
    draft = {
      objectFit: 'cover', cropX: 0.5, cropY: 0.5, cropZoom: 1,
      flipH: false, flipV: false, brightness: 100, contrast: 100, grayscale: 0,
    };
    buildControls();
    updatePreview();
  });
  resetSection.appendChild(resetBtn);
  panel.appendChild(resetSection);
}

// Helpers for building controls
function sec(label: string): HTMLElement {
  const div = document.createElement('div');
  div.className = 'ie-section';
  const lbl = document.createElement('div');
  lbl.className = 'ie-section-label';
  lbl.textContent = label;
  div.appendChild(lbl);
  return div;
}

function slider(
  label: string, id: string, min: number, max: number, step: number,
  value: number, onChange: (v: number) => void
): HTMLElement {
  const row = document.createElement('div');
  row.className = 'ie-slider-row';
  row.innerHTML = `
    <span class="ie-slider-label">${label}</span>
    <input class="ie-slider" id="${id}" type="range" min="${min}" max="${max}" step="${step}" value="${value}">
    <span class="ie-slider-val" id="${id}Val">${Number.isInteger(step) ? value : value.toFixed(1)}</span>
  `;
  const input = row.querySelector('input')!;
  const valSpan = row.querySelector('.ie-slider-val')!;
  input.addEventListener('input', () => {
    const v = parseFloat(input.value);
    valSpan.textContent = Number.isInteger(step) ? String(v) : v.toFixed(1);
    onChange(v);
  });
  return row;
}

// Init: wire overlay events
export function initImageEditor(): void {
  const overlay = getOverlay();
  if (!overlay) return;

  // Close button
  overlay.querySelector('.ie-close')?.addEventListener('click', () => closeImageEditor(false));

  // Click backdrop to close
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeImageEditor(false);
  });

  // Apply button
  document.getElementById('ieApply')?.addEventListener('click', () => closeImageEditor(true));

  // Cancel button
  document.getElementById('ieCancel')?.addEventListener('click', () => closeImageEditor(false));

  // Custom event from props panel
  document.addEventListener('open-image-editor', ((e: CustomEvent) => {
    openImageEditor(e.detail.id);
  }) as EventListener);

  // Escape key (captured in events.ts, but also handle here for safety)
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && overlay.classList.contains('visible')) {
      e.stopPropagation();
      closeImageEditor(false);
    }
  }, true); // capture phase to beat events.ts
}
