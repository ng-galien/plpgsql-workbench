// ============================================================
// TYPES — shared types + client-only declarations
// ============================================================

export type {
  Canvas, Element, TextElement, ImageElement, RectElement, LineElement,
  Document, DocSummary, DocMeta, BBox,
} from "../src/types.js";

declare global {
  const d3: any;
}

export interface AssetImage {
  file: string;
  title?: string;
  description?: string;
  tags?: string[];
  width?: number;
  height?: number;
  orientation?: string;
  saison?: string;
  credit?: string;
  usage_affiche?: string;
}

export interface AssetsData {
  images: AssetImage[];
}
