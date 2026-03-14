// ============================================================
// HELPERS — shared traversal utilities for element trees
// ============================================================

import type { Element } from "./types.js";

/** Find any element by ID, including groups (recursive) */
export function findInElements(elements: Element[], id: string): Element | null {
  for (const el of elements) {
    if (el.id === id) return el;
    if (el.type === 'group') {
      const found = findInElements(el.children, id);
      if (found) return found;
    }
  }
  return null;
}

/** Flatten elements tree to leaf elements (skip groups, recurse into children) */
export function flattenLeaves(elements: Element[]): Element[] {
  const out: Element[] = [];
  for (const el of elements) {
    if (el.type === 'group') {
      out.push(...flattenLeaves(el.children));
    } else {
      out.push(el);
    }
  }
  return out;
}

/** Compute bounding box for any element, including groups (union of children) */
export function elementBBox(el: Element): { x: number; y: number; w: number; h: number } | undefined {
  if (el.type === 'group') {
    if (el.children.length === 0) return undefined;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const child of el.children) {
      const cb = elementBBox(child);
      if (!cb) continue;
      minX = Math.min(minX, cb.x);
      minY = Math.min(minY, cb.y);
      maxX = Math.max(maxX, cb.x + cb.w);
      maxY = Math.max(maxY, cb.y + cb.h);
    }
    if (minX === Infinity) return undefined;
    return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
  }
  if (el.type === 'line') {
    const x = Math.min(el.x1, el.x2), y = Math.min(el.y1, el.y2);
    return { x: x - 1, y: y - 1, w: Math.abs(el.x2 - el.x1) + 2, h: Math.abs(el.y2 - el.y1) + 2 };
  }
  if (el.type === 'text') {
    const textNode = d3.select(`[data-id="${el.id}"]`).node();
    if (textNode) {
      const b = textNode.getBBox();
      return { x: b.x - 1, y: b.y - 1, w: b.width + 2, h: b.height + 2 };
    }
    return undefined;
  }
  // rect or image
  return { x: el.x, y: el.y, w: el.width, h: el.height };
}
