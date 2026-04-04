/**
 * Illustrator types — canvas formats, element interfaces, document model.
 * Ported from mcp-illustrator/src/types.ts.
 */

export const FORMATS: Record<string, { w: number; h: number }> = {
  A2: { w: 420, h: 594 },
  A3: { w: 297, h: 420 },
  A4: { w: 210, h: 297 },
  A5: { w: 148, h: 210 },
  HD: { w: 480, h: 270 },
  MACBOOK: { w: 457, h: 286 },
  IPAD: { w: 341, h: 256 },
  MOBILE: { w: 135, h: 270 },
};

export const SCREEN_FORMATS = new Set(["HD", "MACBOOK", "IPAD", "MOBILE"]);

export interface Canvas {
  id: string;
  format: string;
  orientation: string;
  w: number;
  h: number;
  bg: string;
  name: string;
  category: string;
  meta: DocMeta;
}

export interface BaseElement {
  id: string;
  name?: string;
  type: string;
  opacity: number;
  rotation: number;
}

export interface TextElement extends BaseElement {
  type: "text";
  x: number;
  y: number;
  content: string;
  fontSize: number;
  fontFamily: string;
  fontWeight: string;
  fontStyle: string;
  fill: string;
  textAnchor: string;
  maxWidth: number | null;
}

export interface ImageElement extends BaseElement {
  type: "image";
  x: number;
  y: number;
  width: number;
  height: number;
  assetId: string | null;
  objectFit: "cover" | "contain" | "fill";
  cropX: number;
  cropY: number;
  cropZoom: number;
  flipH: boolean;
  flipV: boolean;
  brightness: number;
  contrast: number;
  grayscale: number;
  borderWidth: number;
  borderColor: string;
  borderRadius: number;
  shadowX: number;
  shadowY: number;
  shadowBlur: number;
  shadowColor: string;
}

export interface RectElement extends BaseElement {
  type: "rect";
  x: number;
  y: number;
  width: number;
  height: number;
  fill: string;
  stroke: string;
  strokeWidth: number;
  rx: number;
}

export interface LineElement extends BaseElement {
  type: "line";
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  stroke: string;
  strokeWidth: number;
}

export interface CircleElement extends BaseElement {
  type: "circle";
  cx: number;
  cy: number;
  r: number;
  fill: string;
  stroke: string;
  strokeWidth: number;
}

export interface EllipseElement extends BaseElement {
  type: "ellipse";
  cx: number;
  cy: number;
  rx: number;
  ry: number;
  fill: string;
  stroke: string;
  strokeWidth: number;
}

export interface PathElement extends BaseElement {
  type: "path";
  d: string;
  fill: string;
  stroke: string;
  strokeWidth: number;
}

export interface GroupElement extends BaseElement {
  type: "group";
  children: Element[];
}

export type Element =
  | TextElement
  | ImageElement
  | RectElement
  | LineElement
  | CircleElement
  | EllipseElement
  | PathElement
  | GroupElement;

export interface DocMeta {
  designNotes?: string;
  teamNotes?: string;
  rating?: number;
}

export interface LoadedCanvas {
  canvas: Canvas;
  elements: Element[];
}

export interface BBox {
  x: number;
  y: number;
  w: number;
  h: number;
}
