// ============================================================
// UI — document selector, layers tree, properties
// ============================================================

import "./styles/tree.css";

import { store } from "./store/index.js";
import { sendLoadDoc, setSelection } from "./ws.js";
import { renderProps } from "./props.js";
import { esc } from "./utils.js";
import type { Element } from "./types.js";

const BADGES: Record<string, string> = { text: 'T', image: 'IMG', rect: 'R', line: 'L', group: 'G' };
const CHEVRON = '<svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M4 2.5l3.5 3.5L4 9.5"/></svg>';

/** Tracks which tree nodes are collapsed (persists across re-renders) */
const collapsedNodes = new Set<string>();

export function r(v: number): number { return Math.round(v * 10) / 10; }

function elLabel(el: Element): string {
  switch (el.type) {
    case 'text': return el.text.split('\n')[0].slice(0, 22);
    case 'image': return el.path ? el.path.replace(/\.[^.]+$/, '') : 'Image';
    case 'rect': return `${r(el.width)} x ${r(el.height)}`;
    case 'line': return 'Ligne';
    case 'group': return el.name || `Groupe (${el.children?.length || 0})`;
  }
}

/** Toggle collapse state and re-render */
function toggleCollapse(key: string): void {
  if (collapsedNodes.has(key)) collapsedNodes.delete(key);
  else collapsedNodes.add(key);
  renderLayersTree();
}

/** Update the doc selector label + dropdown list */
export function renderDocSelector(): void {
  const { doc: { currentDoc, docList } } = store.state;
  const label = document.getElementById('docSelectorLabel');
  if (label) {
    label.textContent = currentDoc ? currentDoc.name : 'Aucun document';
  }

  const listEl = document.getElementById('docDropdownList');
  if (!listEl) return;
  listEl.innerHTML = '';

  // Group by category
  const groups: Record<string, any[]> = {};
  for (const d of docList) {
    const cat = d.category || 'general';
    if (!groups[cat]) groups[cat] = [];
    groups[cat].push(d);
  }

  const activeName = currentDoc?.name;
  for (const cat of Object.keys(groups).sort()) {
    const catDiv = document.createElement('div');
    catDiv.className = 'doc-dd-cat';
    catDiv.textContent = cat;
    listEl.appendChild(catDiv);

    for (const docMeta of groups[cat]) {
      const isActive = docMeta.name === activeName;
      const item = document.createElement('div');
      item.className = 'doc-dd-item' + (isActive ? ' active' : '');
      item.innerHTML = `
        <span>${esc(docMeta.name)}</span>
        <span class="doc-dd-item-meta">
          ${docMeta.rating ? '<span class="doc-dd-item-stars">' + '&#9733;'.repeat(docMeta.rating) + '</span> ' : ''}
          ${docMeta.format || '?'} &middot; ${docMeta.count}
        </span>
      `;
      item.addEventListener('click', () => {
        if (!isActive) sendLoadDoc(docMeta.name);
        closeDocDropdown();
      });
      listEl.appendChild(item);
    }
  }
}

function closeDocDropdown(): void {
  document.getElementById('docSelector')?.classList.remove('open');
  document.getElementById('docDropdown')?.classList.remove('open');
}

/** Render the layers tree in the left panel */
export function renderLayersTree(): void {
  const tree = document.getElementById('tree')!;
  tree.innerHTML = '';

  const { doc: { currentDoc }, ui } = store.state;
  if (!currentDoc) return;

  // Update element count
  const countEl = document.getElementById('layersCount');
  if (countEl) countEl.textContent = String(currentDoc.elements.length);

  // Document root node — same pattern as group nodes
  const docKey = '__doc__';
  const docOpen = !collapsedNodes.has(docKey);
  const { w, h } = currentDoc.canvas;

  const docNode = document.createElement('li');
  docNode.className = 'tree-node';
  docNode.innerHTML = `
    <span class="tree-chevron${docOpen ? ' open' : ''}">${CHEVRON}</span>
    <span class="tree-badge tree-badge--doc">DOC</span>
    <span class="tree-name tree-name--doc">${esc(currentDoc.name)}</span>
    <span class="tree-meta">${currentDoc.canvas.format || `${r(w)}×${r(h)}`}</span>
  `;
  docNode.onclick = (e) => { e.stopPropagation(); setSelection(null); };
  const docChevron = docNode.querySelector('.tree-chevron') as HTMLElement;
  docChevron.onclick = (e) => { e.stopPropagation(); toggleCollapse(docKey); };
  tree.appendChild(docNode);

  // Doc children
  const docChildren = document.createElement('ul');
  docChildren.className = 'tree-children' + (docOpen ? '' : ' collapsed');
  tree.appendChild(docChildren);

  const selectedSet = new Set(ui.selectedIds);
  renderElements(currentDoc.elements, docChildren, selectedSet);
}

/** Recursively render elements into a parent <ul> */
function renderElements(elements: Element[], parent: HTMLElement, selectedIds: Set<string>): void {
  for (const el of elements) {
    if (el.type === 'group') {
      renderGroupNode(el, parent, selectedIds);
    } else {
      renderLeaf(el, parent, selectedIds);
    }
  }
}

/** Render a collapsible group node */
function renderGroupNode(el: Element, parent: HTMLElement, selectedIds: Set<string>): void {
  if (el.type !== 'group') return;
  const isOpen = !collapsedNodes.has(el.id);
  const isSelected = selectedIds.has(el.id);

  const node = document.createElement('li');
  node.className = 'tree-node' + (isSelected ? ' selected' : '');
  node.innerHTML = `
    <span class="tree-chevron${isOpen ? ' open' : ''}">${CHEVRON}</span>
    <span class="tree-badge">G</span>
    <span class="tree-name">${esc(el.name || 'Groupe')}</span>
    <span class="tree-meta">${el.children.length}</span>
  `;
  node.onclick = (e) => { e.stopPropagation(); setSelection(el.id, e.shiftKey || e.metaKey); };
  const chevron = node.querySelector('.tree-chevron') as HTMLElement;
  chevron.onclick = (e) => { e.stopPropagation(); toggleCollapse(el.id); };
  parent.appendChild(node);

  // Group children
  const childrenUl = document.createElement('ul');
  childrenUl.className = 'tree-children' + (isOpen ? '' : ' collapsed');
  parent.appendChild(childrenUl);

  renderElements(el.children, childrenUl, selectedIds);
}

/** Render a leaf element (non-collapsible) */
function renderLeaf(el: Element, parent: HTMLElement, selectedIds: Set<string>): void {
  const isSelected = selectedIds.has(el.id);

  const leaf = document.createElement('li');
  leaf.className = 'tree-leaf' + (isSelected ? ' selected' : '');
  leaf.innerHTML = `
    <span class="tree-badge">${BADGES[el.type] || '?'}</span>
    <span class="tree-name">${esc(elLabel(el))}</span>
    <span class="tree-id">${el.id}</span>
  `;
  leaf.onclick = (e) => { e.stopPropagation(); setSelection(el.id, e.shiftKey || e.metaKey); };
  parent.appendChild(leaf);
}

export function renderUI(): void {
  renderDocSelector();
  renderLayersTree();
  const currentDoc = store.state.doc.currentDoc;
  if (currentDoc) renderProps();
}
