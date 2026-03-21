// ============================================================
// RENDER — SVG rendering engine
// ============================================================

import "./styles/canvas.css";

import { store, dispatch } from "./store/index.js";
import { wrapTextClient } from "./text.js";
import { sendUpdate, setSelection } from "./ws.js";
import { undoManager } from "./history.js";
import { computeSnap, collectSnapTargets } from "./snap.js";
import type { Guide } from "./snap.js";
import type { Element } from "./types.js";
import { findInElements, flattenLeaves, elementBBox } from "./helpers.js";

/** Update snap guide lines inside a persistent SVG group */
function renderGuides(group: any, guides: Guide[]): void {
  group.selectAll('*').remove();
  const doc = store.state.doc.currentDoc;
  if (!doc) return;
  const { canvas } = doc;
  for (const g of guides) {
    if (g.axis === 'v') {
      group.append('line').attr('x1', g.pos).attr('y1', 0).attr('x2', g.pos).attr('y2', canvas.h)
        .attr('stroke', '#3B82F6').attr('stroke-width', 0.5).attr('stroke-dasharray', '2,2').attr('opacity', 0.9);
    } else {
      group.append('line').attr('x1', 0).attr('y1', g.pos).attr('x2', canvas.w).attr('y2', g.pos)
        .attr('stroke', '#3B82F6').attr('stroke-width', 0.5).attr('stroke-dasharray', '2,2').attr('opacity', 0.9);
    }
  }
}
import { toSVG, fitSVG } from "./zoom.js";
import { r } from "./helpers.js";

export function render(): void {
  const { doc: { currentDoc }, ui, ephemeral } = store.state;
  if (!currentDoc) return;
  const { canvas, elements } = currentDoc;

  const svg = d3.select('#canvas');
  const svgEl = document.getElementById('canvas') as HTMLElement;
  svg.attr('viewBox', `0 0 ${canvas.w} ${canvas.h}`).attr('overflow', 'visible');
  svgEl.style.width = canvas.w + 'px';
  svgEl.style.height = canvas.h + 'px';

  // Only re-fit when document or canvas dimensions change
  const fk = `${currentDoc.name}_${canvas.w}_${canvas.h}`;
  if (fk !== store.state.refs.lastFitKey) {
    dispatch({ type: "SET_LAST_FIT_KEY", key: fk });
    fitSVG();
  }

  svg.selectAll('*').remove();

  const defs = svg.append('defs');

  // Background
  svg.append('rect')
    .attr('width', canvas.w).attr('height', canvas.h)
    .attr('fill', canvas.bg)
    .on('click', () => { setSelection(null); });

  // Bleed zone overlay (3mm safety margin)
  if (ui.showBleed) {
    const bleed = 3;
    const bleedGroup = svg.append('g').attr('class', 'bleed-overlay').style('pointer-events', 'none');
    bleedGroup.append('rect').attr('x', 0).attr('y', 0).attr('width', canvas.w).attr('height', bleed).attr('fill', 'rgba(255,0,0,0.08)');
    bleedGroup.append('rect').attr('x', 0).attr('y', canvas.h - bleed).attr('width', canvas.w).attr('height', bleed).attr('fill', 'rgba(255,0,0,0.08)');
    bleedGroup.append('rect').attr('x', 0).attr('y', bleed).attr('width', bleed).attr('height', canvas.h - 2 * bleed).attr('fill', 'rgba(255,0,0,0.08)');
    bleedGroup.append('rect').attr('x', canvas.w - bleed).attr('y', bleed).attr('width', bleed).attr('height', canvas.h - 2 * bleed).attr('fill', 'rgba(255,0,0,0.08)');
    bleedGroup.append('rect')
      .attr('x', bleed).attr('y', bleed)
      .attr('width', canvas.w - 2 * bleed).attr('height', canvas.h - 2 * bleed)
      .attr('fill', 'none').attr('stroke', '#ff0000').attr('stroke-width', 0.3)
      .attr('stroke-dasharray', '2,2').attr('opacity', 0.4);
  }

  elements.forEach((el: Element) => renderElement(svg, defs, el));

  // Flatten for inspector/selection (need leaf elements from inside groups)
  const leaves = flattenLeaves(elements);

  // Inspector overlay (bounding boxes + name labels) — hidden during drag
  if (ui.showNames && store.state.phase !== 'dragging') {
    const overlay = svg.append('g').attr('class', 'inspector-overlay').style('pointer-events', 'none');
    leaves.forEach((el: Element) => renderInspectorBox(overlay, el));
  }

  for (const selId of ui.selectedIds) {
    const sel = findInElements(elements, selId);
    if (sel) renderSelection(svg, sel);
  }
}


function renderElement(svg: any, defs: any, el: Element): void {
  // Groups: recurse into children
  if (el.type === 'group') {
    const groupG = svg.append('g').attr('data-group', el.id);
    if ((el.opacity ?? 1) < 1) groupG.attr('opacity', el.opacity);
    for (const child of el.children) {
      renderElement(groupG, defs, child);
    }
    return;
  }

  const opacity = el.opacity ?? 1;
  const rotation = el.rotation ?? 0;

  // Create SVG filter for images with effects
  if (el.type === 'image') {
    const hasFilter = (el.brightness ?? 100) !== 100 || (el.contrast ?? 100) !== 100 || (el.grayscale ?? 0) > 0;
    const hasShadow = (el.shadowBlur > 0 || el.shadowX || el.shadowY);

    if (hasFilter || hasShadow) {
      const filter = defs.append('filter').attr('id', `f_${el.id}`)
        .attr('x', '-20%').attr('y', '-20%').attr('width', '140%').attr('height', '140%');
      let input = 'SourceGraphic';
      if (hasShadow) {
        filter.append('feDropShadow')
          .attr('dx', el.shadowX || 0).attr('dy', el.shadowY || 0)
          .attr('stdDeviation', el.shadowBlur || 0)
          .attr('flood-color', el.shadowColor || 'rgba(0,0,0,0.4)')
          .attr('flood-opacity', 1)
          .attr('result', 'shadow');
        input = 'shadow';
      }
      if (hasFilter) {
        const sat = 1 - (el.grayscale ?? 0) / 100;
        filter.append('feColorMatrix')
          .attr('type', 'saturate').attr('values', sat)
          .attr('in', input).attr('result', 'gray');
        const b = (el.brightness ?? 100) / 100;
        const c = (el.contrast ?? 100) / 100;
        const ic = (1 - c) * 0.5;
        const ct = filter.append('feComponentTransfer').attr('in', 'gray');
        ct.append('feFuncR').attr('type', 'linear').attr('slope', b * c).attr('intercept', ic);
        ct.append('feFuncG').attr('type', 'linear').attr('slope', b * c).attr('intercept', ic);
        ct.append('feFuncB').attr('type', 'linear').attr('slope', b * c).attr('intercept', ic);
      }
    }

    // Crop clip path for cover mode
    const fit = el.objectFit || 'cover';
    if (fit === 'cover') {
      const cp = defs.append('clipPath').attr('id', `c_${el.id}`);
      if (el.borderRadius > 0) {
        cp.append('rect').attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height)
          .attr('rx', el.borderRadius);
      } else {
        cp.append('rect').attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height);
      }
    }
  }

  // Wrap in group for transforms
  const g = svg.append('g');
  if (opacity < 1) g.attr('opacity', opacity);
  if (rotation !== 0) {
    let cx: number, cy: number;
    if (el.type === 'line') {
      cx = (el.x1 + el.x2) / 2; cy = (el.y1 + el.y2) / 2;
    } else if (el.type === 'text') {
      cx = el.x; cy = el.y;
    } else {
      cx = el.x + ((el as any).width || 0) / 2; cy = el.y + ((el as any).height || 0) / 2;
    }
    g.attr('transform', `rotate(${rotation}, ${cx}, ${cy})`);
  }

  let node: any;

  switch (el.type) {
    case 'rect':
      node = g.append('rect')
        .attr('x', el.x).attr('y', el.y)
        .attr('width', el.width).attr('height', el.height)
        .attr('fill', el.fill).attr('stroke', el.stroke)
        .attr('stroke-width', el.strokeWidth).attr('rx', el.rx);
      break;

    case 'line':
      node = g.append('line')
        .attr('x1', el.x1).attr('y1', el.y1)
        .attr('x2', el.x2).attr('y2', el.y2)
        .attr('stroke', el.stroke).attr('stroke-width', el.strokeWidth);
      break;

    case 'image': {
      const hasFilter = (el.brightness ?? 100) !== 100 || (el.contrast ?? 100) !== 100 || (el.grayscale ?? 0) > 0;
      const hasShadow = (el.shadowBlur > 0 || el.shadowX || el.shadowY);
      const filterAttr = (hasFilter || hasShadow) ? `url(#f_${el.id})` : null;
      const fit = el.objectFit || 'cover';

      // Flip transform string (applied around frame center)
      const flipH = el.flipH ? -1 : 1, flipV = el.flipV ? -1 : 1;
      const needFlip = flipH === -1 || flipV === -1;
      const fcx = el.x + el.width / 2, fcy = el.y + el.height / 2;
      const flipTransform = needFlip
        ? `translate(${fcx},${fcy}) scale(${flipH},${flipV}) translate(${-fcx},${-fcy})`
        : '';

      if (fit === 'cover' && el.naturalWidth > 0 && el.naturalHeight > 0) {
        // Cover: scale image to fill frame, crop with clipPath, position via cropX/cropY
        const frameW = el.width, frameH = el.height;
        const natW = el.naturalWidth, natH = el.naturalHeight;
        const zoom = el.cropZoom || 1;
        const baseScale = Math.max(frameW / natW, frameH / natH);
        const scale = baseScale * zoom;
        const imgW = natW * scale, imgH = natH * scale;
        const cropX = el.cropX ?? 0.5, cropY = el.cropY ?? 0.5;
        const imgX = el.x - (imgW - frameW) * cropX;
        const imgY = el.y - (imgH - frameH) * cropY;

        const imgG = g.append('g')
          .attr('clip-path', `url(#c_${el.id})`)
          .style('pointer-events', 'none');
        if (flipTransform) imgG.attr('transform', flipTransform);

        const img = imgG.append('image')
          .attr('x', imgX).attr('y', imgY)
          .attr('width', imgW).attr('height', imgH)
          .attr('href', el.href)
          .attr('preserveAspectRatio', 'none');
        if (filterAttr) img.attr('filter', filterAttr);

        // Transparent hit rect for interaction (drag moves this rect; image re-renders on state update)
        node = g.append('rect')
          .attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height)
          .attr('fill', 'transparent');

      } else if (fit === 'contain') {
        // Contain: fit inside frame, no clip
        if (flipTransform) {
          g.attr('transform', (g.attr('transform') || '') + ' ' + flipTransform);
        }
        node = g.append('image')
          .attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height)
          .attr('href', el.href)
          .attr('preserveAspectRatio', 'xMidYMid meet');
        if (filterAttr) node.attr('filter', filterAttr);

      } else {
        // Fill: stretch to fit, no clip
        if (flipTransform) {
          g.attr('transform', (g.attr('transform') || '') + ' ' + flipTransform);
        }
        node = g.append('image')
          .attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height)
          .attr('href', el.href)
          .attr('preserveAspectRatio', 'none');
        if (filterAttr) node.attr('filter', filterAttr);
      }

      // Border
      if (el.borderWidth > 0) {
        g.append('rect')
          .attr('x', el.x).attr('y', el.y)
          .attr('width', el.width).attr('height', el.height)
          .attr('fill', 'none')
          .attr('stroke', el.borderColor || '#000')
          .attr('stroke-width', el.borderWidth)
          .attr('rx', el.borderRadius || 0)
          .style('pointer-events', 'none');
      }
      break;
    }

    case 'text': {
      const lines = el.maxWidth
        ? wrapTextClient(el.text, el.maxWidth, el.fontSize, el.fontFamily, el.fontWeight, el.fontStyle)
        : el.text.split('\n');
      const lh = el.fontSize * 1.3;
      node = g.append('text')
        .attr('x', el.x).attr('y', el.y)
        .attr('font-family', el.fontFamily)
        .attr('font-size', el.fontSize)
        .attr('font-weight', el.fontWeight)
        .attr('font-style', el.fontStyle)
        .attr('fill', el.fill)
        .attr('text-anchor', el.textAnchor);

      lines.forEach((line: string, i: number) => {
        const tspan = node.append('tspan').text(line);
        if (i > 0) { tspan.attr('x', el.x).attr('dy', lh); }
      });

      // Visual maxWidth guide when selected
      if (el.maxWidth && store.state.ui.selectedIds.includes(el.id)) {
        const totalH = lines.length * lh;
        let gx = el.x;
        if (el.textAnchor === 'middle') gx -= el.maxWidth / 2;
        else if (el.textAnchor === 'end') gx -= el.maxWidth;
        svg.append('rect')
          .attr('class', 'maxwidth-guide')
          .attr('x', gx).attr('y', el.y - el.fontSize * 0.85)
          .attr('width', el.maxWidth).attr('height', totalH)
          .attr('fill', 'none')
          .attr('stroke', '#3B82F6').attr('stroke-width', 0.3)
          .attr('stroke-dasharray', '1.5,1')
          .style('pointer-events', 'none');
      }
      break;
    }
  }

  if (!node) return;

  node.attr('class', 'element').attr('data-id', el.id);

  // Skip interaction handlers when document is locked (pan mode)
  if (store.state.ui.documentLocked) return;

  node.on('click', (event: any) => {
    event.stopPropagation();
    const toggle = event.shiftKey || event.metaKey;
    setSelection(el.id, toggle);
  });

  // Double-click on image opens editor modal
  if (el.type === 'image') {
    node.on('dblclick', (event: any) => {
      event.stopPropagation();
      document.dispatchEvent(new CustomEvent('open-image-editor', { detail: { id: el.id } }));
    });
  }

  const dragBehavior = d3.drag()
    .on('start', function (this: any, event: any) {
      const selectedIds = store.state.ui.selectedIds;
      const isInSelection = selectedIds.includes(el.id);

      // If dragging an element not in the selection, select it first
      if (!isInSelection) {
        setSelection(el.id);
        this._multiDrag = null;
      }

      dispatch({ type: "DRAG_START", elId: el.id });
      const svgPt = toSVG(event.sourceEvent);

      // Record primary element offset
      if (el.type === 'line') {
        this._ox1 = el.x1 - svgPt.x; this._oy1 = el.y1 - svgPt.y;
        this._ox2 = el.x2 - svgPt.x; this._oy2 = el.y2 - svgPt.y;
        this._startProps = { x1: el.x1, y1: el.y1, x2: el.x2, y2: el.y2 };
      } else {
        this._ox = (el as any).x - svgPt.x; this._oy = (el as any).y - svgPt.y;
        this._startProps = { x: (el as any).x, y: (el as any).y };
      }

      // Multi-drag: record start positions of all OTHER selected elements
      const dragIds = isInSelection ? selectedIds : [el.id];
      if (dragIds.length > 1) {
        const doc = store.state.doc.currentDoc;
        if (doc) {
          const others: Array<{ el: Element; start: any }> = [];
          for (const sid of dragIds) {
            if (sid === el.id) continue;
            const other = findInElements(doc.elements, sid);
            if (!other) continue;
            if (other.type === 'line') {
              others.push({ el: other, start: { x1: other.x1, y1: other.y1, x2: other.x2, y2: other.y2 } });
            } else if (other.type !== 'group') {
              others.push({ el: other, start: { x: (other as any).x, y: (other as any).y } });
            }
          }
          this._multiDrag = others;
        }
      } else {
        this._multiDrag = null;
      }

      // Pre-compute snap targets excluding all dragged elements
      const doc = store.state.doc.currentDoc;
      if (store.state.ui.snapEnabled && doc) {
        this._snapTargets = collectSnapTargets(doc.elements, new Set(dragIds), doc.canvas);
      } else {
        this._snapTargets = null;
      }
      this._guideGroup = d3.select('#canvas').append('g').attr('class', 'snap-guides').style('pointer-events', 'none');
      d3.select('.inspector-overlay').style('display', 'none');
    })
    .on('drag', function (this: any, event: any) {
      const svgPt = toSVG(event.sourceEvent);
      let dx = 0, dy = 0;

      if (el.type === 'line') {
        let x1 = svgPt.x + this._ox1, y1 = svgPt.y + this._oy1;
        let x2 = svgPt.x + this._ox2, y2 = svgPt.y + this._oy2;
        if (this._snapTargets) {
          const lx = Math.min(x1, x2), ly = Math.min(y1, y2);
          const lw = Math.abs(x2 - x1) || 0.5, lh = Math.abs(y2 - y1) || 0.5;
          const snap = computeSnap({ x: lx, y: ly, w: lw, h: lh }, this._snapTargets);
          const sdx = snap.x - lx, sdy = snap.y - ly;
          x1 += sdx; y1 += sdy; x2 += sdx; y2 += sdy;
          dispatch({ type: "DRAG_MOVE", snapGuides: snap.guides });
          renderGuides(this._guideGroup, snap.guides);
        }
        dx = x1 - el.x1; dy = y1 - el.y1;
        el.x1 = x1; el.y1 = y1; el.x2 = x2; el.y2 = y2;
        d3.select(this).attr('x1', el.x1).attr('y1', el.y1).attr('x2', el.x2).attr('y2', el.y2);
      } else {
        let newX = svgPt.x + this._ox;
        let newY = svgPt.y + this._oy;
        if (this._snapTargets) {
          let bx = newX, by = newY;
          let w = (el as any).width || 0, h = (el as any).height || 0;
          if (el.type === 'text') {
            const tw = (el as any).maxWidth || (el.text.length * el.fontSize * 0.55);
            const th = el.fontSize * 1.3 * (el.text.split("\n").length);
            bx = (el as any).textAnchor === "middle" ? newX - tw / 2 : (el as any).textAnchor === "end" ? newX - tw : newX;
            by = newY - el.fontSize * 0.85;
            w = tw; h = th;
          }
          const snap = computeSnap({ x: bx, y: by, w, h }, this._snapTargets);
          newX += snap.x - bx;
          newY += snap.y - by;
          dispatch({ type: "DRAG_MOVE", snapGuides: snap.guides });
          renderGuides(this._guideGroup, snap.guides);
        }
        dx = newX - (el as any).x; dy = newY - (el as any).y;
        (el as any).x = newX; (el as any).y = newY;
        d3.select(this).attr('x', (el as any).x).attr('y', (el as any).y);
        if (el.type === 'text') {
          d3.select(this).selectAll('tspan')
            .filter(function (this: any) { return d3.select(this).attr('x') !== null; })
            .attr('x', (el as any).x);
        }
      }

      // Move other selected elements by the same delta
      if (this._multiDrag && (dx !== 0 || dy !== 0)) {
        for (const { el: other } of this._multiDrag) {
          if (other.type === 'line') {
            other.x1 += dx; other.y1 += dy; other.x2 += dx; other.y2 += dy;
            const n = d3.select(`[data-id="${other.id}"]`);
            n.attr('x1', other.x1).attr('y1', other.y1).attr('x2', other.x2).attr('y2', other.y2);
          } else if (other.type !== 'group') {
            (other as any).x += dx; (other as any).y += dy;
            const n = d3.select(`[data-id="${other.id}"]`);
            n.attr('x', (other as any).x).attr('y', (other as any).y);
            if (other.type === 'text') {
              n.selectAll('tspan')
                .filter(function (this: any) { return d3.select(this).attr('x') !== null; })
                .attr('x', (other as any).x);
            }
          }
        }
      }

      d3.selectAll('.selection-rect').remove();
      const svg = d3.select('#canvas');
      renderSelection(svg, el);
      if (this._multiDrag) {
        for (const { el: other } of this._multiDrag) renderSelection(svg, other);
      }
    })
    .on('end', function (this: any) {
      dispatch({ type: "DRAG_END" });
      this._guideGroup?.remove();
      d3.select('.inspector-overlay').style('display', null);

      // Collect all undo/redo entries
      const undoEntries: Array<{ id: string; oldProps: any; newProps: any }> = [];

      if (el.type === 'line') {
        const newProps = { x1: r(el.x1), y1: r(el.y1), x2: r(el.x2), y2: r(el.y2) };
        undoEntries.push({ id: el.id, oldProps: this._startProps, newProps });
        sendUpdate(el.id, newProps);
      } else {
        const newProps = { x: r((el as any).x), y: r((el as any).y) };
        undoEntries.push({ id: el.id, oldProps: this._startProps, newProps });
        sendUpdate(el.id, newProps);
      }

      if (this._multiDrag) {
        for (const { el: other, start } of this._multiDrag) {
          let newProps: any;
          if (other.type === 'line') {
            newProps = { x1: r(other.x1), y1: r(other.y1), x2: r(other.x2), y2: r(other.y2) };
          } else if (other.type !== 'group') {
            newProps = { x: r((other as any).x), y: r((other as any).y) };
          }
          if (newProps) {
            undoEntries.push({ id: other.id, oldProps: start, newProps });
            sendUpdate(other.id, newProps);
          }
        }
      }

      // Single compound undo entry
      const moved = undoEntries.filter(e => {
        const o = e.oldProps, n = e.newProps;
        return o.x !== n.x || o.y !== n.y || o.x1 !== n.x1 || o.y1 !== n.y1;
      });
      if (moved.length > 0) {
        undoManager.push({
          label: `Drag ${moved.length} element(s)`,
          undo: () => { for (const e of moved) sendUpdate(e.id, e.oldProps); },
          redo: () => { for (const e of moved) sendUpdate(e.id, e.newProps); },
        });
      }
    });
  node.call(dragBehavior);
}


function renderSelection(svg: any, el: Element): void {
  const bbox = elementBBox(el);
  if (!bbox) return;
  svg.append('rect').attr('class', 'selection-rect')
    .attr('x', bbox.x - 1).attr('y', bbox.y - 1)
    .attr('width', bbox.w + 2).attr('height', bbox.h + 2);
}

function renderInspectorBox(overlay: any, el: Element): void {
  let bx: number, by: number, bw: number, bh: number;
  if (el.type === 'line') {
    bx = Math.min(el.x1, el.x2);
    by = Math.min(el.y1, el.y2);
    bw = Math.abs(el.x2 - el.x1) || 0.5;
    bh = Math.abs(el.y2 - el.y1) || 0.5;
  } else if (el.type === 'text') {
    const textNode = d3.select(`[data-id="${el.id}"]`).node();
    if (textNode) {
      const b = textNode.getBBox();
      bx = b.x; by = b.y; bw = b.width; bh = b.height;
    } else {
      bx = el.x; by = el.y - el.fontSize; bw = 20; bh = el.fontSize;
    }
  } else if (el.type === 'rect' || el.type === 'image') {
    bx = el.x; by = el.y; bw = el.width; bh = el.height;
  } else {
    return; // groups are not passed to this function
  }

  const isSelected = store.state.ui.selectedIds.includes(el.id);
  const color = isSelected ? '#8f6b1a' : '#5B8A72';
  const label = el.name || el.id;

  overlay.append('rect')
    .attr('x', bx).attr('y', by)
    .attr('width', bw).attr('height', bh)
    .attr('fill', 'none')
    .attr('stroke', color)
    .attr('stroke-width', 0.3)
    .attr('stroke-dasharray', el.name ? 'none' : '1,1')
    .attr('opacity', isSelected ? 0.9 : 0.45);

  const fontSize = 1.8;
  const padX = 1;
  const padY = 0.4;
  const textW = label.length * fontSize * 0.52;
  const pillW = textW + padX * 2;
  const pillH = fontSize + padY * 2;

  overlay.append('rect')
    .attr('x', bx)
    .attr('y', by - pillH)
    .attr('width', pillW)
    .attr('height', pillH)
    .attr('rx', 0.8)
    .attr('fill', color)
    .attr('opacity', isSelected ? 0.95 : 0.7);

  overlay.append('text')
    .attr('x', bx + padX)
    .attr('y', by - padY)
    .attr('font-family', 'Outfit, sans-serif')
    .attr('font-size', fontSize)
    .attr('font-weight', el.name ? 600 : 400)
    .attr('fill', '#ffffff')
    .text(label);
}
