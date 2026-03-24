import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { get } from "@/lib/api";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

// --- Types ---

interface SduiNode {
  type: string;
  [key: string]: unknown;
}

interface Datasource {
  uri: string;
  page_size?: number;
  searchable?: boolean;
  default_sort?: string;
}

interface SduiProps {
  ui: SduiNode;
  datasources?: Record<string, Datasource>;
}

interface ColDef {
  key: string;
  label: string;
  cell?: SduiNode;
}

// --- Template interpolation ---

function interpolate(template: string, row: Record<string, unknown>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => String(row[key] ?? ""));
}

function resolveCell(cell: SduiNode, row: Record<string, unknown>): SduiNode {
  const resolved: Record<string, unknown> = { type: cell.type };
  for (const [k, v] of Object.entries(cell)) {
    if (k === "type") continue;
    resolved[k] = typeof v === "string" ? interpolate(v, row) : v;
  }
  return resolved as SduiNode;
}

// --- Renderer ---

export function SduiRenderer({ ui, datasources }: SduiProps) {
  return <RenderNode node={ui} datasources={datasources ?? {}} />;
}

function RenderNode({
  node,
  datasources,
}: {
  node: SduiNode;
  datasources: Record<string, Datasource>;
}) {
  switch (node.type) {
    case "column":
      return (
        <div className="flex flex-col gap-4">
          {(node.children as SduiNode[])?.map((child, i) => (
            <RenderNode key={i} node={child} datasources={datasources} />
          ))}
        </div>
      );

    case "row":
      return (
        <div className="flex gap-4 items-center flex-wrap">
          {(node.children as SduiNode[])?.map((child, i) => (
            <RenderNode key={i} node={child} datasources={datasources} />
          ))}
        </div>
      );

    case "heading": {
      const level = (node.level as number) ?? 2;
      if (level === 1)
        return (
          <h1 className="text-2xl font-semibold tracking-tight">
            {node.text as string}
          </h1>
        );
      if (level === 3)
        return (
          <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-wider mt-2">
            {node.text as string}
          </h3>
        );
      return (
        <h2 className="text-xl font-semibold tracking-tight">
          {node.text as string}
        </h2>
      );
    }

    case "text":
      return (
        <span className="text-sm text-muted-foreground">
          {node.value as string}
        </span>
      );

    case "link":
      return (
        <Link
          to={node.href as string}
          className="text-sm text-primary hover:underline"
        >
          {node.text as string}
        </Link>
      );

    case "badge":
      return <SduiBadge text={node.text as string} variant={node.variant as string} />;

    case "color":
      return <ColorSwatch value={node.value as string} />;

    case "table":
      return (
        <SduiTable
          source={node.source as string}
          columns={node.columns as ColDef[]}
          datasource={datasources[node.source as string]}
        />
      );

    case "action":
      return (
        <button
          onClick={async () => {
            if (node.confirm && !window.confirm(node.confirm as string)) return;
            const { crud } = await import("@/lib/api");
            await crud(node.verb as string, node.uri as string);
          }}
          className={`inline-flex items-center px-3 py-1.5 text-sm font-medium rounded-md border cursor-pointer transition-colors ${
            node.variant === "danger"
              ? "bg-destructive/10 text-destructive border-destructive/20 hover:bg-destructive/20"
              : "bg-card text-foreground border-border hover:bg-accent"
          }`}
        >
          {node.label as string}
        </button>
      );

    default:
      return (
        <span className="text-xs text-muted-foreground">
          [unknown: {node.type}]
        </span>
      );
  }
}

// --- Connected table ---

function SduiTable({
  source,
  columns,
  datasource,
}: {
  source: string;
  columns: ColDef[];
  datasource?: Datasource;
}) {
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!datasource) {
      setError(`Datasource "${source}" not found`);
      setLoading(false);
      return;
    }
    get(datasource.uri)
      .then((res) => setRows(res?.data ?? []))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [datasource?.uri]);

  if (loading)
    return <p className="text-sm text-muted-foreground">Chargement...</p>;
  if (error) return <p className="text-sm text-destructive">{error}</p>;
  if (rows.length === 0)
    return <p className="text-sm text-muted-foreground">Aucun résultat.</p>;

  return (
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            {columns.map((col) => (
              <TableHead
                key={col.key}
                className="text-xs font-medium text-muted-foreground"
              >
                {col.label}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((row, i) => (
            <TableRow key={i}>
              {columns.map((col) => (
                <TableCell key={col.key}>
                  {col.cell ? (
                    <CellRenderer cell={resolveCell(col.cell, row)} />
                  ) : (
                    <span className="text-sm">
                      {String(row[col.key] ?? "")}
                    </span>
                  )}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

function CellRenderer({ cell }: { cell: SduiNode }) {
  switch (cell.type) {
    case "link":
      return (
        <Link
          to={cell.href as string}
          className="text-sm font-medium text-foreground hover:text-primary transition-colors"
        >
          {cell.text as string}
        </Link>
      );
    case "badge":
      return <SduiBadge text={cell.text as string} variant={cell.variant as string} />;
    case "color":
      return <ColorSwatch value={cell.value as string} />;
    case "text":
      return <span className="text-sm">{cell.value as string}</span>;
    default:
      return (
        <span className="text-sm">
          {String(cell.text ?? cell.value ?? "")}
        </span>
      );
  }
}

// --- Primitives ---

const badgeVariants: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  draft: "secondary",
  generated: "default",
  signed: "default",
  archived: "outline",
  active: "default",
  inactive: "destructive",
};

function SduiBadge({ text, variant }: { text: string; variant?: string }) {
  const v = variant ?? text.toLowerCase();
  const shadcnVariant = badgeVariants[v] ?? "secondary";
  return (
    <Badge variant={shadcnVariant} className="font-normal">
      {text}
    </Badge>
  );
}

function ColorSwatch({ value }: { value: string }) {
  return (
    <span className="inline-flex items-center gap-2">
      <span
        className="w-4 h-4 rounded-sm border inline-block"
        style={{ background: value }}
      />
      <code className="text-xs text-muted-foreground">{value}</code>
    </span>
  );
}
