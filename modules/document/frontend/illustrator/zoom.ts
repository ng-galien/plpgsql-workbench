// ============================================================
// ZOOM — D3 zoom, pan, coordinate transforms
// ============================================================

import { store, dispatch } from "./store/index.js";

export function toSVG(mouseEvent: MouseEvent): SVGPoint {
  const svg = document.getElementById('canvas') as unknown as SVGSVGElement;
  const pt = svg.createSVGPoint();
  pt.x = mouseEvent.clientX;
  pt.y = mouseEvent.clientY;
  return pt.matrixTransform(svg.getScreenCTM()!.inverse());
}

export function fitSVG(animate = false): void {
  const currentDoc = store.state.doc.currentDoc;
  const zoomBehavior = store.state.refs.zoomBehavior;
  if (!currentDoc || !zoomBehavior) return;
  const area = document.querySelector('.canvas-viewport') as HTMLElement;
  if (!area) return;
  const svgEl = document.getElementById('canvas') as HTMLElement;
  const { w, h } = currentDoc.canvas;

  svgEl.style.width = w + 'px';
  svgEl.style.height = h + 'px';

  const pad = 40;
  const aW = area.clientWidth - pad * 2;
  const aH = area.clientHeight - pad * 2;
  if (aW <= 0 || aH <= 0) return;
  const k = Math.min(aW / w, aH / h, 3);
  const tx = (area.clientWidth - w * k) / 2;
  const ty = (area.clientHeight - h * k) / 2;

  const t = d3.zoomIdentity.translate(tx, ty).scale(k);
  const sel = d3.select('.canvas-viewport');
  if (animate) {
    sel.transition().duration(300).ease(d3.easeCubicOut).call(zoomBehavior.transform, t);
  } else {
    sel.call(zoomBehavior.transform, t);
  }
}

export function initZoom(): void {
  const zoomBehavior = d3.zoom()
    .scaleExtent([0.15, 8])
    .filter((event: any) => {
      if (event.type === 'wheel') return true;
      if (event.type === 'dblclick') return true;
      if (store.state.ui.documentLocked) return true;
      const t = event.target;
      if (t.classList && t.classList.contains('element')) return false;
      if (t.closest && t.closest('.element')) return false;
      return true;
    })
    .on('zoom', (event: any) => {
      const wrap = document.querySelector('.svg-wrap') as HTMLElement;
      if (!wrap) return;
      const { x, y, k } = event.transform;
      wrap.style.transform = `translate(${x}px, ${y}px) scale(${k})`;

      // Update zoom level display
      const pct = Math.round(k * 100);
      dispatch({ type: "SET_ZOOM_LEVEL", level: k });
      const label = document.getElementById('zoomLabel');
      if (label) label.textContent = pct + '%';
      const slider = document.getElementById('zoomSlider') as HTMLInputElement;
      if (slider) slider.value = String(pct);
    });

  dispatch({ type: "SET_ZOOM_BEHAVIOR", behavior: zoomBehavior });

  const viewport = d3.select('.canvas-viewport');
  viewport.call(zoomBehavior);
  viewport.on('dblclick.zoom', () => fitSVG(true));
}
