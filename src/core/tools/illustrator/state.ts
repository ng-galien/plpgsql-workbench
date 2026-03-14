/**
 * State loader — loads canvas + elements from PG into in-memory types.
 * Used by every tool that needs to read the document state.
 */

import type { DbClient } from "../../connection.js";
import type {
  Canvas,
  CircleElement,
  Element,
  EllipseElement,
  GroupElement,
  ImageElement,
  LineElement,
  LoadedCanvas,
  PathElement,
  RectElement,
  TextElement,
} from "./types.js";

/** Load a canvas with all its elements, reconstructed as a nested tree. */
export async function loadCanvas(client: DbClient, canvasId: string): Promise<LoadedCanvas | null> {
  const { rows: canvasRows } = await client.query(
    `SELECT id, name, format, orientation, width, height, background, category, meta
     FROM document.canvas WHERE id = $1`,
    [canvasId],
  );
  if (canvasRows.length === 0) return null;
  const c = canvasRows[0];

  const canvas: Canvas = {
    id: c.id,
    format: c.format,
    orientation: c.orientation,
    w: c.width,
    h: c.height,
    bg: c.background,
    name: c.name,
    category: c.category,
    meta: c.meta ?? {},
  };

  const { rows: elementRows } = await client.query(
    `SELECT id, type, parent_id, sort_order, name,
            x, y, width, height, x1, y1, x2, y2, cx, cy, r, rx_, ry_,
            opacity, rotation, fill, stroke, stroke_width, stroke_dasharray,
            props, asset_id
     FROM document.element
     WHERE canvas_id = $1
     ORDER BY sort_order`,
    [canvasId],
  );

  const elements = buildTree(elementRows);
  return { canvas, elements };
}

/** Resolve a canvas by name or UUID. */
export async function resolveCanvasId(client: DbClient, nameOrId: string): Promise<string | null> {
  const { rows } = await client.query(`SELECT id FROM document.canvas WHERE id::text = $1 OR name = $1 LIMIT 1`, [
    nameOrId,
  ]);
  return rows.length > 0 ? rows[0].id : null;
}

/** Compact LMNAV representation of canvas state. */
export function compactState(loaded: LoadedCanvas): string {
  const c = loaded.canvas;
  const total = countElements(loaded.elements);
  const lines: string[] = [];

  lines.push(
    `Canvas: "${c.name}" [${c.category}] ${c.format} ${c.orientation} ${c.w}x${c.h}mm bg:${c.bg} | ${total} elements`,
  );
  lines.push("─".repeat(60));

  for (const el of loaded.elements) {
    renderElement(el, 0, lines);
  }

  return lines.join("\n");
}

function renderElement(el: Element, indent: number, lines: string[]): void {
  const pad = "  ".repeat(indent);
  const nameTag = el.name ? ` (${el.name})` : "";
  const id = el.id.slice(0, 8);

  switch (el.type) {
    case "text": {
      const t = el as TextElement;
      const preview = t.content.length > 30 ? `${t.content.slice(0, 27)}...` : t.content;
      lines.push(`${pad}${id}${nameTag}  text  "${preview}" x:${t.x} y:${t.y} sz:${t.fontSize} fill:${t.fill}`);
      break;
    }
    case "rect": {
      const r = el as RectElement;
      lines.push(`${pad}${id}${nameTag}  rect  x:${r.x} y:${r.y} ${r.width}x${r.height}mm fill:${r.fill}`);
      break;
    }
    case "line": {
      const l = el as LineElement;
      lines.push(`${pad}${id}${nameTag}  line  (${l.x1},${l.y1}) -> (${l.x2},${l.y2}) stroke:${l.stroke}`);
      break;
    }
    case "circle": {
      const ci = el as CircleElement;
      lines.push(`${pad}${id}${nameTag}  circle  cx:${ci.cx} cy:${ci.cy} r:${ci.r} fill:${ci.fill}`);
      break;
    }
    case "image": {
      const img = el as ImageElement;
      lines.push(`${pad}${id}${nameTag}  image  x:${img.x} y:${img.y} ${img.width}x${img.height}mm`);
      break;
    }
    case "group": {
      const g = el as GroupElement;
      lines.push(`${pad}${id}${nameTag}  group  [${g.children.length} children]`);
      for (const child of g.children) {
        renderElement(child, indent + 1, lines);
      }
      break;
    }
    default:
      lines.push(`${pad}${id}${nameTag}  ${el.type}`);
  }
}

function countElements(elements: Element[]): number {
  let count = 0;
  for (const el of elements) {
    count++;
    if (el.type === "group") {
      count += countElements((el as GroupElement).children);
    }
  }
  return count;
}

// --- Tree reconstruction from flat PG rows ---

function buildTree(rows: any[]): Element[] {
  const byId = new Map<string, any>();
  const childrenMap = new Map<string, any[]>();

  for (const row of rows) {
    byId.set(row.id, row);
    const parentId = row.parent_id ?? "__root__";
    if (!childrenMap.has(parentId)) childrenMap.set(parentId, []);
    childrenMap.get(parentId)!.push(row);
  }

  function buildNode(row: any): Element {
    const base = {
      id: row.id,
      name: row.name ?? undefined,
      opacity: row.opacity ?? 1,
      rotation: row.rotation ?? 0,
    };
    const props = row.props ?? {};

    switch (row.type) {
      case "text":
        return {
          ...base,
          type: "text",
          x: row.x,
          y: row.y,
          content: props.content ?? "",
          fontSize: props.fontSize ?? 8,
          fontFamily: props.fontFamily ?? "Libre Baskerville",
          fontWeight: props.fontWeight ?? "bold",
          fontStyle: props.fontStyle ?? "normal",
          fill: row.fill ?? "#1C1C1C",
          textAnchor: props.textAnchor ?? "start",
          maxWidth: props.maxWidth ?? null,
        } as TextElement;

      case "rect":
        return {
          ...base,
          type: "rect",
          x: row.x,
          y: row.y,
          width: row.width,
          height: row.height,
          fill: row.fill ?? "#000000",
          stroke: row.stroke ?? "none",
          strokeWidth: row.stroke_width ?? 0,
          rx: props.rx ?? 0,
        } as RectElement;

      case "line":
        return {
          ...base,
          type: "line",
          x1: row.x1,
          y1: row.y1,
          x2: row.x2,
          y2: row.y2,
          stroke: row.stroke ?? "#000000",
          strokeWidth: row.stroke_width ?? 0.5,
        } as LineElement;

      case "circle":
        return {
          ...base,
          type: "circle",
          cx: row.cx,
          cy: row.cy,
          r: row.r,
          fill: row.fill ?? "#000000",
          stroke: row.stroke ?? "none",
          strokeWidth: row.stroke_width ?? 0,
        } as CircleElement;

      case "ellipse":
        return {
          ...base,
          type: "ellipse",
          cx: row.cx,
          cy: row.cy,
          rx: row.rx_,
          ry: row.ry_,
          fill: row.fill ?? "#000000",
          stroke: row.stroke ?? "none",
          strokeWidth: row.stroke_width ?? 0,
        } as EllipseElement;

      case "image":
        return {
          ...base,
          type: "image",
          x: row.x,
          y: row.y,
          width: row.width,
          height: row.height,
          assetId: row.asset_id ?? null,
          objectFit: props.objectFit ?? "cover",
          cropX: props.cropX ?? 0.5,
          cropY: props.cropY ?? 0.5,
          cropZoom: props.cropZoom ?? 1,
          flipH: props.flipH ?? false,
          flipV: props.flipV ?? false,
          brightness: props.brightness ?? 100,
          contrast: props.contrast ?? 100,
          grayscale: props.grayscale ?? 0,
          borderWidth: props.borderWidth ?? 0,
          borderColor: props.borderColor ?? "#000000",
          borderRadius: props.borderRadius ?? 0,
          shadowX: props.shadowX ?? 0,
          shadowY: props.shadowY ?? 0,
          shadowBlur: props.shadowBlur ?? 0,
          shadowColor: props.shadowColor ?? "rgba(0,0,0,0.4)",
        } as ImageElement;

      case "path":
        return {
          ...base,
          type: "path",
          d: props.d ?? "",
          fill: row.fill ?? "none",
          stroke: row.stroke ?? "#000000",
          strokeWidth: row.stroke_width ?? 0.5,
        } as PathElement;

      case "group": {
        const children = (childrenMap.get(row.id) ?? []).map(buildNode);
        return {
          ...base,
          type: "group",
          children,
        } as GroupElement;
      }

      default:
        return { ...base, type: row.type } as any;
    }
  }

  const roots = childrenMap.get("__root__") ?? [];
  return roots.map(buildNode);
}
