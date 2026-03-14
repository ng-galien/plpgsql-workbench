// ============================================================
// PROPS — element and document properties panel
// ============================================================

import "./styles/props.css";

import { store, dispatch } from "./store/index.js";
import { sendUpdate, sendDelete, sendUpdateCanvas, sendUpdateMeta, setSelection } from "./ws.js";
import { esc, showConfirmBar } from "./utils.js";
import { undoManager } from "./history.js";
import { findInElements } from "./helpers.js";
import type { Element } from "./types.js";

export function renderProps(): void {
  const content = document.getElementById('propsContent')!;
  const { doc: { currentDoc }, ui } = store.state;

  if (ui.selectedIds.length === 0 || !currentDoc) {
    renderDocProps(content);
    return;
  }
  // Multi-selection: show summary
  if (ui.selectedIds.length > 1) {
    renderMultiProps(content, ui.selectedIds.length);
    return;
  }
  const el = findInElements(currentDoc.elements, ui.selectedIds[0]);
  if (!el) { renderDocProps(content); return; }

  document.getElementById('propsTitle')!.textContent = 'Proprietes';
  content.innerHTML = '';

  const addProp = (label: string, key: string, type = 'text') => {
    if ((el as any)[key] === undefined || (el as any)[key] === null) return;
    const val = (el as any)[key];
    if (type === 'color' && (val === 'none' || !/^#[0-9a-fA-F]{3,8}$/.test(val))) return;
    const row = document.createElement('div');
    row.className = 'prop-row';

    if (type === 'textarea') {
      row.innerHTML = `<span class="prop-label">${label}</span><textarea class="prop-textarea">${esc(String(val))}</textarea>`;
      const ta = row.querySelector('textarea')!;
      ta.addEventListener('focus', () => dispatch({ type: "PHASE_TRANSITION", to: "editing_prop" }));
      ta.addEventListener('blur', () => dispatch({ type: "PHASE_TRANSITION", to: ui.selectedIds.length > 0 ? "selected" : "idle" }));
      ta.addEventListener('change', () => {
        const oldVal = (el as any)[key];
        undoManager.push({ label: `${key} ${el.id}`, undo: () => sendUpdate(el.id, { [key]: oldVal }), redo: () => sendUpdate(el.id, { [key]: ta.value }) });
        (el as any)[key] = ta.value; sendUpdate(el.id, { [key]: ta.value });
      });
    } else {
      row.innerHTML = `<span class="prop-label">${label}</span><input class="prop-input" type="${type}" value="${type === 'color' ? val : esc(String(val))}">`;
      const inp = row.querySelector('input')!;
      inp.addEventListener('focus', () => dispatch({ type: "PHASE_TRANSITION", to: "editing_prop" }));
      inp.addEventListener('blur', () => dispatch({ type: "PHASE_TRANSITION", to: ui.selectedIds.length > 0 ? "selected" : "idle" }));
      inp.addEventListener('change', () => {
        let v: any = inp.value; if (type === 'number') v = parseFloat(v) || 0;
        const oldVal = (el as any)[key];
        undoManager.push({ label: `${key} ${el.id}`, undo: () => sendUpdate(el.id, { [key]: oldVal }), redo: () => sendUpdate(el.id, { [key]: v }) });
        (el as any)[key] = v; sendUpdate(el.id, { [key]: v });
      });
    }
    content.appendChild(row);
  };

  const addRange = (label: string, key: string, min: number, max: number, step = 1) => {
    const val = (el as any)[key] ?? min;
    const row = document.createElement('div');
    row.className = 'prop-row';
    row.innerHTML = `
      <span class="prop-label">${label}</span>
      <input class="prop-range" type="range" min="${min}" max="${max}" step="${step}" value="${val}">
      <span class="prop-range-val">${val}</span>
    `;
    const range = row.querySelector('.prop-range') as HTMLInputElement;
    const valSpan = row.querySelector('.prop-range-val')!;
    range.addEventListener('input', () => { valSpan.textContent = range.value; });
    range.addEventListener('change', () => {
      const v = parseFloat(range.value);
      const oldVal = (el as any)[key];
      undoManager.push({ label: `${key} ${el.id}`, undo: () => sendUpdate(el.id, { [key]: oldVal }), redo: () => sendUpdate(el.id, { [key]: v }) });
      (el as any)[key] = v;
      sendUpdate(el.id, { [key]: v });
    });
    content.appendChild(row);
  };

  const addSelect = (label: string, key: string, options: string[]) => {
    if ((el as any)[key] === undefined || (el as any)[key] === null) return;
    const row = document.createElement('div');
    row.className = 'prop-row';
    const opts = options.map(o => `<option value="${o}"${(el as any)[key] === o ? ' selected' : ''}>${esc(o)}</option>`).join('');
    row.innerHTML = `<span class="prop-label">${label}</span><select class="prop-select">${opts}</select>`;
    const sel = row.querySelector('select')!;
    sel.addEventListener('change', () => {
      const oldVal = (el as any)[key];
      undoManager.push({ label: `${key} ${el.id}`, undo: () => sendUpdate(el.id, { [key]: oldVal }), redo: () => sendUpdate(el.id, { [key]: sel.value }) });
      (el as any)[key] = sel.value; sendUpdate(el.id, { [key]: sel.value });
    });
    content.appendChild(row);
  };

  const addSeparator = (label?: string) => {
    const hr = document.createElement('hr');
    hr.className = 'prop-separator';
    content.appendChild(hr);
    if (label) {
      const lbl = document.createElement('div');
      lbl.className = 'prop-section-label';
      lbl.textContent = label;
      content.appendChild(lbl);
    }
  };

  // ---- Position ----
  addProp('X', 'x', 'number');
  addProp('Y', 'y', 'number');

  if (el.type === 'rect' || el.type === 'image') {
    addProp('W', 'width', 'number');
    addProp('H', 'height', 'number');
  }
  if (el.type === 'line') {
    addProp('X1', 'x1', 'number');
    addProp('Y1', 'y1', 'number');
    addProp('X2', 'x2', 'number');
    addProp('Y2', 'y2', 'number');
  }

  // ---- Common: opacity & rotation ----
  addSeparator('Apparence');
  addRange('Opa', 'opacity', 0, 1, 0.05);
  addRange('Rot', 'rotation', -180, 180, 1);

  // ---- Type-specific ----
  if (el.type === 'text') {
    addSeparator('Texte');
    addProp('Txt', 'text', 'textarea');
    addProp('Px', 'fontSize', 'number');
    addSelect('Police', 'fontFamily', ['Libre Baskerville', 'Source Sans 3']);
    addSelect('Poids', 'fontWeight', ['normal', '300', 'bold', '600', '700']);
    addSelect('Style', 'fontStyle', ['normal', 'italic']);
    addSelect('Align', 'textAnchor', ['start', 'middle', 'end']);
    // maxWidth
    const mwRow = document.createElement('div');
    mwRow.className = 'prop-row';
    const mwVal = (el as any).maxWidth ?? '';
    mwRow.innerHTML = `<span class="prop-label">LMax</span><input class="prop-input" type="number" step="1" min="0" placeholder="auto" value="${mwVal}">`;
    const mwInp = mwRow.querySelector('input')!;
    mwInp.addEventListener('change', () => {
      const v = mwInp.value ? parseFloat(mwInp.value) || null : null;
      (el as any).maxWidth = v;
      sendUpdate(el.id, { maxWidth: v });
    });
    content.appendChild(mwRow);
    addProp('Coul', 'fill', 'color');
  }

  if (el.type === 'rect') {
    addSeparator('Rect');
    addProp('Fond', 'fill', 'color');
    addProp('Bord', 'stroke', 'color');
    addProp('Ep', 'strokeWidth', 'number');
    addProp('R', 'rx', 'number');
  }

  if (el.type === 'line') {
    addSeparator('Ligne');
    addProp('Coul', 'stroke', 'color');
    addProp('Ep', 'strokeWidth', 'number');
  }

  if (el.type === 'image') {
    addSeparator('Image');
    addSelect('Fit', 'objectFit', ['cover', 'contain', 'fill']);

    // Flip toggles
    const flipRow = document.createElement('div');
    flipRow.className = 'prop-row';
    flipRow.innerHTML = `<span class="prop-label">Flip</span><div class="prop-flip-btns">
      <button class="prop-flip-btn${el.flipH ? ' active' : ''}" data-dir="H" title="Miroir H">↔</button>
      <button class="prop-flip-btn${el.flipV ? ' active' : ''}" data-dir="V" title="Miroir V">↕</button>
    </div>`;
    flipRow.querySelectorAll('.prop-flip-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const dir = (btn as HTMLElement).dataset.dir;
        const key = dir === 'H' ? 'flipH' : 'flipV';
        const oldVal = (el as any)[key];
        const newVal = !oldVal;
        undoManager.push({ label: `${key} ${el.id}`, undo: () => sendUpdate(el.id, { [key]: oldVal }), redo: () => sendUpdate(el.id, { [key]: newVal }) });
        (el as any)[key] = newVal;
        sendUpdate(el.id, { [key]: newVal });
      });
    });
    content.appendChild(flipRow);

    // Edit image button (opens modal)
    const editRow = document.createElement('div');
    editRow.className = 'prop-row';
    const editBtn = document.createElement('button');
    editBtn.className = 'btn-edit-image';
    editBtn.textContent = 'Modifier l\u2019image';
    editBtn.onclick = () => {
      const evt = new CustomEvent('open-image-editor', { detail: { id: el.id } });
      document.dispatchEvent(evt);
    };
    editRow.appendChild(editBtn);
    content.appendChild(editRow);

    addSeparator('Filtres');
    addRange('Lum', 'brightness', 50, 150, 1);
    addRange('Ctr', 'contrast', 50, 150, 1);
    addRange('N&B', 'grayscale', 0, 100, 1);

    addSeparator('Bordure');
    addProp('Ep', 'borderWidth', 'number');
    addProp('Coul', 'borderColor', 'color');
    addProp('R', 'borderRadius', 'number');

    addSeparator('Ombre');
    addProp('dX', 'shadowX', 'number');
    addProp('dY', 'shadowY', 'number');
    addProp('Flou', 'shadowBlur', 'number');
    addProp('Coul', 'shadowColor', 'text');
  }

  // ---- Delete button ----
  addSeparator();
  const delWrap = document.createElement('div');
  delWrap.className = 'prop-delete-wrap';
  const delBtn = document.createElement('button');
  delBtn.className = 'btn-delete-element';
  delBtn.textContent = 'Supprimer';
  delBtn.onclick = () => showConfirmBar(delBtn, 'Supprimer cet element ?', () => { sendDelete(el.id); setSelection(null); });
  delWrap.appendChild(delBtn);
  content.appendChild(delWrap);
}

function renderMultiProps(content: HTMLElement, count: number): void {
  document.getElementById('propsTitle')!.textContent = 'Selection';
  content.innerHTML = '';
  const info = document.createElement('div');
  info.className = 'prop-section-label';
  info.textContent = `${count} elements selectionnes`;
  content.appendChild(info);

  const hr = document.createElement('hr');
  hr.className = 'prop-separator';
  content.appendChild(hr);

  const delWrap = document.createElement('div');
  delWrap.className = 'prop-delete-wrap';
  const delBtn = document.createElement('button');
  delBtn.className = 'btn-delete-element';
  delBtn.textContent = `Supprimer (${count})`;
  delBtn.onclick = () => showConfirmBar(delBtn, `Supprimer ${count} elements ?`, () => {
    const ids = store.state.ui.selectedIds;
    for (const id of ids) sendDelete(id);
    setSelection(null);
  });
  delWrap.appendChild(delBtn);
  content.appendChild(delWrap);
}

function renderDocProps(content: HTMLElement): void {
  const currentDoc = store.state.doc.currentDoc;
  if (!currentDoc) { content.innerHTML = ''; return; }
  document.getElementById('propsTitle')!.textContent = 'Document';
  content.innerHTML = '';

  const { canvas } = currentDoc;
  const formats = ['A2', 'A3', 'A4', 'A5'];

  // Format select
  const fmtRow = document.createElement('div');
  fmtRow.className = 'prop-row';
  const opts = formats.map(f => `<option value="${f}"${canvas.format === f ? ' selected' : ''}>${f}</option>`).join('');
  fmtRow.innerHTML = `<span class="prop-label">Format</span><select class="prop-select">${opts}</select>`;
  const fmtSel = fmtRow.querySelector('select')!;
  fmtSel.addEventListener('change', () => sendUpdateCanvas({ format: fmtSel.value }));
  content.appendChild(fmtRow);

  // Orientation toggle
  const orient = canvas.orientation || 'portrait';
  const oriRow = document.createElement('div');
  oriRow.className = 'prop-row';
  const oriOpts = ['portrait', 'paysage'].map(o => `<option value="${o}"${orient === o ? ' selected' : ''}>${o}</option>`).join('');
  oriRow.innerHTML = `<span class="prop-label">Orient</span><select class="prop-select">${oriOpts}</select>`;
  const oriSel = oriRow.querySelector('select')!;
  oriSel.addEventListener('change', () => sendUpdateCanvas({ orientation: oriSel.value }));
  content.appendChild(oriRow);

  // Dimensions (read-only)
  const dimRow = document.createElement('div');
  dimRow.className = 'prop-row';
  dimRow.innerHTML = `<span class="prop-label">Dim</span><span class="prop-dim">${canvas.w} x ${canvas.h} mm</span>`;
  content.appendChild(dimRow);

  // Background color
  const bgRow = document.createElement('div');
  bgRow.className = 'prop-row';
  bgRow.innerHTML = `<span class="prop-label">Fond</span><input class="prop-input" type="color" value="${canvas.bg}">`;
  const bgInp = bgRow.querySelector('input')!;
  bgInp.addEventListener('change', () => sendUpdateCanvas({ bg: bgInp.value }));
  content.appendChild(bgRow);

  // ---- Meta section ----
  const meta = currentDoc.meta || {};

  const metaSep = document.createElement('hr');
  metaSep.className = 'prop-separator';
  content.appendChild(metaSep);
  const metaLabel = document.createElement('div');
  metaLabel.className = 'prop-section-label';
  metaLabel.textContent = 'Notes & Evaluation';
  content.appendChild(metaLabel);

  // Rating (stars)
  const ratingRow = document.createElement('div');
  ratingRow.className = 'prop-row';
  const currentRating = meta.rating || 0;
  ratingRow.innerHTML = `<span class="prop-label">Note</span><div class="star-rating" data-rating="${currentRating}">${
    [1,2,3,4,5].map(i => `<span class="star${i <= currentRating ? ' active' : ''}" data-val="${i}">&#9733;</span>`).join('')
  }</div>`;
  const stars = ratingRow.querySelectorAll('.star');
  const ratingWrap = ratingRow.querySelector('.star-rating')!;
  stars.forEach(star => {
    star.addEventListener('click', () => {
      const val = parseInt((star as HTMLElement).dataset.val!);
      const newVal = val === currentRating ? 0 : val;
      sendUpdateMeta({ rating: newVal });
    });
    star.addEventListener('mouseenter', () => {
      const hv = parseInt((star as HTMLElement).dataset.val!);
      stars.forEach(s => {
        s.classList.toggle('hovered', parseInt((s as HTMLElement).dataset.val!) <= hv);
        s.classList.remove('active');
      });
    });
  });
  ratingWrap.addEventListener('mouseleave', () => {
    stars.forEach(s => {
      s.classList.remove('hovered');
      s.classList.toggle('active', parseInt((s as HTMLElement).dataset.val!) <= currentRating);
    });
  });
  content.appendChild(ratingRow);

  // Design notes
  const dnRow = document.createElement('div');
  dnRow.className = 'prop-row prop-row-col';
  dnRow.innerHTML = `<span class="prop-label-full">Insights design (Claude)</span><textarea class="prop-textarea" placeholder="Notes de conception...">${esc(meta.designNotes || '')}</textarea>`;
  const dnTa = dnRow.querySelector('textarea')!;
  dnTa.addEventListener('change', () => sendUpdateMeta({ designNotes: dnTa.value }));
  content.appendChild(dnRow);

  // Team notes
  const tnRow = document.createElement('div');
  tnRow.className = 'prop-row prop-row-col';
  tnRow.innerHTML = `<span class="prop-label-full">Retours equipe</span><textarea class="prop-textarea" placeholder="Commentaires de l'equipe...">${esc(meta.teamNotes || '')}</textarea>`;
  const tnTa = tnRow.querySelector('textarea')!;
  tnTa.addEventListener('change', () => sendUpdateMeta({ teamNotes: tnTa.value }));
  content.appendChild(tnRow);
}
