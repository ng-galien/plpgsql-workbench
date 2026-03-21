// ============================================================
// SNAP — Magnetic alignment guides
// ============================================================

import type { Element } from "./types.js";
import { flattenLeaves } from "./helpers.js";

export interface Guide {
  axis: "h" | "v";
  pos: number;
}

export interface SnapResult {
  x: number;
  y: number;
  guides: Guide[];
}

export interface SnapTargets {
  xSnaps: number[];
  ySnaps: number[];
}

interface BBox { x: number; y: number; w: number; h: number; }

const THRESHOLD = 2; // mm

function elBbox(el: Element): BBox {
  if (el.type === "line") {
    const x = Math.min(el.x1, el.x2), y = Math.min(el.y1, el.y2);
    return { x, y, w: Math.abs(el.x2 - el.x1) || 0.5, h: Math.abs(el.y2 - el.y1) || 0.5 };
  }
  if (el.type === "text") {
    const tw = el.maxWidth || (el.text.length * el.fontSize * 0.55);
    const th = el.fontSize * 1.3 * (el.text.split("\n").length);
    let tx = el.x;
    if (el.textAnchor === "middle") tx -= tw / 2;
    else if (el.textAnchor === "end") tx -= tw;
    return { x: tx, y: el.y - el.fontSize * 0.85, w: tw, h: th };
  }
  return { x: (el as any).x, y: (el as any).y, w: (el as any).width || 0, h: (el as any).height || 0 };
}

/** Pre-compute snap points once at drag start (#11) */
export function collectSnapTargets(
  elements: Element[],
  excludeIds: Set<string>,
  canvas: { w: number; h: number },
): SnapTargets {
  const xSnaps = [0, canvas.w / 2, canvas.w];
  const ySnaps = [0, canvas.h / 2, canvas.h];
  for (const el of flattenLeaves(elements)) {
    if (excludeIds.has(el.id)) continue;
    const b = elBbox(el);
    xSnaps.push(b.x, b.x + b.w / 2, b.x + b.w);
    ySnaps.push(b.y, b.y + b.h / 2, b.y + b.h);
  }
  return { xSnaps, ySnaps };
}

export function computeSnap(
  dragBbox: BBox,
  targets: SnapTargets,
): SnapResult {
  const { xSnaps, ySnaps } = targets;

  const dLeft = dragBbox.x;
  const dCenterX = dragBbox.x + dragBbox.w / 2;
  const dRight = dragBbox.x + dragBbox.w;
  const dTop = dragBbox.y;
  const dCenterY = dragBbox.y + dragBbox.h / 2;
  const dBottom = dragBbox.y + dragBbox.h;

  let bestDx = Infinity;
  let snapX = dragBbox.x;
  let guideX: number | null = null;

  for (const sx of xSnaps) {
    for (const anchor of [dLeft, dCenterX, dRight]) {
      const dist = Math.abs(anchor - sx);
      if (dist < THRESHOLD && dist < Math.abs(bestDx)) {
        bestDx = anchor - sx;
        snapX = dragBbox.x - bestDx;
        guideX = sx;
      }
    }
  }

  let bestDy = Infinity;
  let snapY = dragBbox.y;
  let guideY: number | null = null;

  for (const sy of ySnaps) {
    for (const anchor of [dTop, dCenterY, dBottom]) {
      const dist = Math.abs(anchor - sy);
      if (dist < THRESHOLD && dist < Math.abs(bestDy)) {
        bestDy = anchor - sy;
        snapY = dragBbox.y - bestDy;
        guideY = sy;
      }
    }
  }

  const guides: Guide[] = [];
  if (guideX !== null) guides.push({ axis: "v", pos: guideX });
  if (guideY !== null) guides.push({ axis: "h", pos: guideY });

  return { x: snapX, y: snapY, guides };
}
