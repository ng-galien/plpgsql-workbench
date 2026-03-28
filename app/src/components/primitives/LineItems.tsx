import { useEffect, useState } from "react";
import { Table, TableBody, TableCell, TableFooter, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { get } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { Currency } from "./Currency";

interface ColDef {
  key: string;
  label: string;
  type?: string; // text, currency, number
  align?: string;
}

interface Totals {
  ht?: number;
  tva?: number;
  ttc?: number;
  [key: string]: number | undefined;
}

export function LineItems({
  source,
  columns,
  totals,
  parentUri,
}: {
  source: string;
  columns: ColDef[];
  totals?: Totals;
  parentUri?: string;
}) {
  const t = useT();
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(!!parentUri);

  useEffect(() => {
    if (!parentUri) return;
    get(parentUri)
      .then((res) => {
        const data = res?.data as Record<string, unknown> | null;
        if (data && Array.isArray(data[source])) {
          setRows(data[source] as Record<string, unknown>[]);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [parentUri, source]);

  if (loading) return <p className="text-xs text-muted-foreground">Loading...</p>;
  if (!rows.length && !totals) return null;

  return (
    <div className="rounded-md border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            {columns.map((col) => (
              <TableHead
                key={col.key}
                className={`text-xs ${col.type === "currency" || col.type === "number" ? "text-right" : ""}`}
              >
                {col.label.includes(".") ? t(col.label) : col.label}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((row, i) => (
            <TableRow key={i}>
              {columns.map((col) => (
                <TableCell
                  key={col.key}
                  className={`text-xs ${col.type === "currency" || col.type === "number" ? "text-right" : ""}`}
                >
                  <CellValue value={row[col.key]} type={col.type} />
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
        {totals && (
          <TableFooter>
            <TableRow className="font-medium">
              <TableCell colSpan={Math.max(1, columns.length - 1)} className="text-xs">
                Total
              </TableCell>
              <TableCell className="text-right text-xs">
                {totals.ttc != null ? (
                  <Currency amount={totals.ttc} />
                ) : totals.ht != null ? (
                  <Currency amount={totals.ht} />
                ) : null}
              </TableCell>
            </TableRow>
            {totals.ht != null && totals.tva != null && totals.ttc != null && (
              <>
                <TableRow>
                  <TableCell colSpan={Math.max(1, columns.length - 1)} className="text-[10px] text-muted-foreground">
                    HT
                  </TableCell>
                  <TableCell className="text-right text-[10px] text-muted-foreground">
                    <Currency amount={totals.ht} />
                  </TableCell>
                </TableRow>
                <TableRow>
                  <TableCell colSpan={Math.max(1, columns.length - 1)} className="text-[10px] text-muted-foreground">
                    TVA
                  </TableCell>
                  <TableCell className="text-right text-[10px] text-muted-foreground">
                    <Currency amount={totals.tva} />
                  </TableCell>
                </TableRow>
              </>
            )}
          </TableFooter>
        )}
      </Table>
    </div>
  );
}

function CellValue({ value, type }: { value: unknown; type?: string }) {
  if (value == null) return <>—</>;
  if (type === "currency") return <Currency amount={Number(value)} />;
  if (type === "number") return <span className="tabular-nums">{String(value)}</span>;
  return <>{String(value)}</>;
}
