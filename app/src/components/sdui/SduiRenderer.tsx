import { useEffect, useState } from "react";
import { Currency } from "@/components/primitives/Currency";
import { LineItems } from "@/components/primitives/LineItems";
import { Timeline } from "@/components/primitives/Timeline";
import { Workflow } from "@/components/primitives/Workflow";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { get } from "@/lib/api";
import type { SduiActionNode, SduiNode } from "@/lib/sdui";
import { getSduiDataForSource } from "@/lib/sdui";
import { fieldKey, fieldLabel, fieldType, formatDate, formatDatetime } from "@/lib/utils";

interface SduiRendererProps {
  node: SduiNode;
  data?: Record<string, unknown>;
  parentUri?: string;
  values?: Record<string, unknown>;
  t: (key: string) => string;
  onAction?: (action: SduiActionNode) => Promise<void> | void;
  onFieldChange?: (key: string, value: unknown) => void;
}

export function SduiRenderer({ node, data, parentUri, values, t, onAction, onFieldChange }: SduiRendererProps) {
  switch (node.type) {
    case "column":
      return (
        <div className="flex flex-col gap-3">
          {node.children.map((child, index) => (
            <SduiNodeSlot
              key={nodeKey(child, index)}
              node={child}
              data={data}
              parentUri={parentUri}
              values={values}
              t={t}
              onAction={onAction}
              onFieldChange={onFieldChange}
            />
          ))}
        </div>
      );

    case "row":
      return (
        <div className="flex flex-wrap items-start gap-2">
          {node.children.map((child, index) => (
            <SduiNodeSlot
              key={nodeKey(child, index)}
              node={child}
              data={data}
              parentUri={parentUri}
              values={values}
              t={t}
              onAction={onAction}
              onFieldChange={onFieldChange}
            />
          ))}
        </div>
      );

    case "section":
      return (
        <div className="flex flex-col gap-2">
          <span className="text-[10px] text-muted-foreground uppercase tracking-widest font-semibold">
            {translate(node.label, t)}
          </span>
          <div className="flex flex-col gap-2">
            {node.children.map((child, index) => (
              <SduiNodeSlot
                key={nodeKey(child, index)}
                node={child}
                data={data}
                parentUri={parentUri}
                values={values}
                t={t}
                onAction={onAction}
                onFieldChange={onFieldChange}
              />
            ))}
          </div>
        </div>
      );

    case "field":
      return <SduiFieldControl field={node.field} value={values?.[node.field.key]} t={t} onChange={onFieldChange} />;

    case "heading": {
      const Tag = node.level && node.level <= 2 ? "h3" : "h4";
      return <Tag className="font-semibold text-sm">{translate(node.text, t)}</Tag>;
    }

    case "text":
      return <span className="text-sm">{translate(node.value, t)}</span>;

    case "badge":
      return (
        <Badge variant={mapBadgeVariant(node.variant)} className="text-[10px] font-normal">
          {translate(node.text, t)}
        </Badge>
      );

    case "color":
      return (
        <span className="inline-flex items-center gap-1">
          <span className="w-3 h-3 rounded-sm border inline-block" style={{ background: node.value }} />
          <code className="text-[10px]">{node.value}</code>
        </span>
      );

    case "md":
      return <div className="text-sm whitespace-pre-wrap">{node.content}</div>;

    case "stat":
      return (
        <div className="flex flex-col gap-0.5 min-w-0">
          <span className={`text-base font-bold ${node.variant === "warning" ? "text-amber-600" : "text-foreground"}`}>
            {node.value}
          </span>
          <span className="text-[10px] text-muted-foreground">{translate(node.label, t)}</span>
        </div>
      );

    case "currency":
      return <Currency amount={node.amount} currency={node.currency} />;

    case "workflow":
      return <Workflow states={node.states.map((state) => translate(state, t))} current={translate(node.current, t)} />;

    case "timeline":
      return (
        <Timeline
          events={node.events.map((event) => ({
            ...event,
            label: translate(event.label, t),
          }))}
        />
      );

    case "detail":
      return <SduiDetail fields={node.fields} data={getSourceRecord(data, node.source)} t={t} />;

    case "table":
      return <SduiTable source={node.source} columns={node.columns} data={data} t={t} />;

    case "line_items":
      return <LineItems source={node.source} columns={node.columns} totals={node.totals} parentUri={parentUri} />;

    case "action":
      return <SduiActionButton action={node} t={t} onAction={onAction} />;
  }
}

function SduiNodeSlot(props: SduiRendererProps) {
  return <SduiRenderer {...props} />;
}

function SduiFieldControl({
  field,
  value,
  t,
  onChange,
}: {
  field: {
    key: string;
    type: string;
    label: string;
    required?: boolean;
    options?: unknown;
    source?: string;
    display?: string;
  };
  value: unknown;
  t: (key: string) => string;
  onChange?: (key: string, value: unknown) => void;
}) {
  const label = translate(field.label, t);
  const inputClass = "w-full px-3 py-1.5 bg-muted rounded-md text-sm border-none outline-none";
  const setValue = (nextValue: unknown) => {
    onChange?.(field.key, nextValue);
  };

  switch (field.type) {
    case "select": {
      const options: Array<{ value: string; label: string } | string> = Array.isArray(field.options)
        ? field.options
        : [];
      return (
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted-foreground">
            {label}
            {field.required && <span className="text-destructive ml-0.5">*</span>}
          </span>
          <select value={String(value ?? "")} onChange={(event) => setValue(event.target.value)} className={inputClass}>
            <option value="">—</option>
            {options.map((option) => {
              const optionValue = typeof option === "string" ? option : option.value;
              const optionLabel = typeof option === "string" ? option : translate(option.label, t);
              return (
                <option key={optionValue} value={optionValue}>
                  {optionLabel}
                </option>
              );
            })}
          </select>
        </label>
      );
    }

    case "textarea":
      return (
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted-foreground">
            {label}
            {field.required && <span className="text-destructive ml-0.5">*</span>}
          </span>
          <textarea
            value={String(value ?? "")}
            onChange={(event) => setValue(event.target.value)}
            className={`${inputClass} resize-none`}
            rows={3}
          />
        </label>
      );

    case "combobox":
      return (
        <SduiComboboxField field={field} value={value} label={label} inputClass={inputClass} onChange={setValue} />
      );

    case "checkbox":
      return (
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={!!value}
            onChange={(event) => setValue(event.target.checked)}
            className="rounded"
          />
          <span className="text-xs text-muted-foreground">{label}</span>
        </label>
      );

    default:
      return (
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted-foreground">
            {label}
            {field.required && <span className="text-destructive ml-0.5">*</span>}
          </span>
          <input
            type={
              field.type === "email"
                ? "email"
                : field.type === "tel"
                  ? "tel"
                  : field.type === "number"
                    ? "number"
                    : "text"
            }
            value={String(value ?? "")}
            onChange={(event) =>
              setValue(
                field.type === "number"
                  ? event.target.value === ""
                    ? null
                    : Number(event.target.value)
                  : event.target.value,
              )
            }
            className={inputClass}
          />
        </label>
      );
  }
}

function SduiComboboxField({
  field,
  value,
  label,
  inputClass,
  onChange,
}: {
  field: { source?: string; display?: string; required?: boolean };
  value: unknown;
  label: string;
  inputClass: string;
  onChange: (value: unknown) => void;
}) {
  const [search, setSearch] = useState("");
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  const displayKey = field.display ?? "name";
  const selectedLabel = rows.find((row) => String(row.id) === String(value))?.[displayKey];

  useEffect(() => {
    if (!field.source) return;
    setLoading(true);
    get(field.source)
      .then((result) => setRows(result?.data ?? []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [field.source]);

  const filtered = search
    ? rows.filter((row) =>
        String(row[displayKey] ?? "")
          .toLowerCase()
          .includes(search.toLowerCase()),
      )
    : rows;

  return (
    <label className="flex flex-col gap-1 relative">
      <span className="text-xs text-muted-foreground">
        {label}
        {field.required && <span className="text-destructive ml-0.5">*</span>}
      </span>
      <div className="relative">
        <input
          type="text"
          value={open ? search : selectedLabel ? String(selectedLabel) : ""}
          onChange={(event) => {
            setSearch(event.target.value);
            if (!open) setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
          placeholder={selectedLabel ? String(selectedLabel) : "Rechercher..."}
          className={inputClass}
        />
        {!!value && !open && (
          <button
            type="button"
            onClick={() => {
              onChange(null);
              setSearch("");
            }}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground text-xs"
          >
            ×
          </button>
        )}
      </div>
      {open && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-card border rounded-md shadow-lg z-30 max-h-48 overflow-auto">
          {loading ? (
            <div className="px-3 py-2 text-xs text-muted-foreground">Loading...</div>
          ) : filtered.length === 0 ? (
            <div className="px-3 py-2 text-xs text-muted-foreground">No results.</div>
          ) : (
            filtered.map((row) => {
              const id = String(row.id ?? "");
              const name = String(row[displayKey] ?? id);
              const isSelected = String(value) === id;
              return (
                <button
                  key={id}
                  type="button"
                  className={`px-3 py-2 text-sm cursor-pointer transition-colors ${
                    isSelected ? "bg-primary/10 text-primary" : "hover:bg-accent"
                  }`}
                  onMouseDown={(event) => {
                    event.preventDefault();
                    onChange(id !== "" && !Number.isNaN(Number(id)) ? Number(id) : id);
                    setSearch("");
                    setOpen(false);
                  }}
                >
                  {name}
                </button>
              );
            })
          )}
        </div>
      )}
    </label>
  );
}

function SduiDetail({
  fields,
  data,
  t,
}: {
  fields: Array<string | { key: string; type?: string; label?: string }>;
  data?: Record<string, unknown>;
  t: (key: string) => string;
}) {
  if (!data) return null;

  return (
    <div className="flex flex-col gap-1">
      {fields.map((field) => {
        const key = fieldKey(field);
        const value = data[key];
        if (value == null || value === "") return null;
        const explicitLabel = fieldLabel(field);
        const label = explicitLabel ? t(explicitLabel) : humanize(key);
        return (
          <div key={key} className="flex justify-between gap-2">
            <span className="text-muted-foreground text-xs">{label}</span>
            <span className="text-xs text-right truncate max-w-[60%]">
              <FieldValue value={value} type={fieldType(field)} />
            </span>
          </div>
        );
      })}
    </div>
  );
}

function SduiTable({
  source,
  columns,
  data,
  t,
}: {
  source: string;
  columns: Array<{ key: string; label: string; type?: string; align?: string }>;
  data?: Record<string, unknown>;
  t: (key: string) => string;
}) {
  const rows = Array.isArray(data?.[source]) ? (data[source] as Record<string, unknown>[]) : [];
  if (rows.length === 0) return null;

  return (
    <div className="rounded-md border bg-card">
      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            {columns.map((column) => (
              <TableHead
                key={column.key}
                className={column.type === "currency" || column.type === "number" ? "text-right text-xs" : "text-xs"}
              >
                {translate(column.label, t)}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={String(row.id ?? row.key ?? JSON.stringify(row))}>
              {columns.map((column) => (
                <TableCell
                  key={column.key}
                  className={column.type === "currency" || column.type === "number" ? "text-right text-xs" : "text-xs"}
                >
                  <FieldValue value={row[column.key]} type={column.type} />
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

function SduiActionButton({
  action,
  t,
  onAction,
}: {
  action: SduiActionNode;
  t: (key: string) => string;
  onAction?: (action: SduiActionNode) => Promise<void> | void;
}) {
  const [loading, setLoading] = useState(false);

  async function handleClick() {
    if (!onAction) return;
    setLoading(true);
    try {
      await onAction(action);
    } finally {
      setLoading(false);
    }
  }

  return (
    <button
      onClick={() => {
        void handleClick();
      }}
      disabled={loading || !onAction}
      className={`px-2.5 py-1 text-xs border rounded-md transition-colors ${mapActionVariant(action.variant)}`}
    >
      {loading ? "..." : translate(action.label, t)}
    </button>
  );
}

function getSourceRecord(
  data: Record<string, unknown> | undefined,
  source: string,
): Record<string, unknown> | undefined {
  if (!data) return undefined;
  const resolved = getSduiDataForSource(data, source);
  if (typeof resolved === "object" && resolved !== null && !Array.isArray(resolved)) {
    return resolved as Record<string, unknown>;
  }
  return source === "self" ? data : undefined;
}

function translate(value: string, t: (key: string) => string): string {
  return value.includes(".") ? t(value) : value;
}

function humanize(key: string): string {
  return key.replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase());
}

function mapBadgeVariant(variant?: string): "default" | "secondary" | "destructive" | "outline" {
  switch (variant) {
    case "danger":
    case "destructive":
      return "destructive";
    case "secondary":
    case "muted":
      return "secondary";
    case "outline":
      return "outline";
    default:
      return "default";
  }
}

function mapActionVariant(variant?: string): string {
  switch (variant) {
    case "danger":
      return "border-destructive/30 text-destructive hover:bg-destructive/10";
    case "warning":
      return "border-amber-300 text-amber-700 hover:bg-amber-50";
    case "primary":
      return "border-primary/30 text-primary hover:bg-primary/10";
    default:
      return "hover:bg-accent";
  }
}

function nodeKey(node: SduiNode, index: number): string {
  switch (node.type) {
    case "action":
      return `action:${node.verb}:${node.uri}`;
    case "badge":
      return `badge:${node.text}:${index}`;
    case "stat":
      return `stat:${node.label}:${index}`;
    case "heading":
      return `heading:${node.text}:${index}`;
    case "text":
      return `text:${node.value}:${index}`;
    case "section":
      return `section:${node.label}:${index}`;
    case "detail":
      return `detail:${node.source}:${index}`;
    case "table":
      return `table:${node.source}:${index}`;
    case "line_items":
      return `line_items:${node.source}:${index}`;
    default:
      return `${node.type}:${index}`;
  }
}

function FieldValue({ value, type }: { value: unknown; type?: string }) {
  if (value === true) return <Badge variant="default">Yes</Badge>;
  if (value === false) return <Badge variant="secondary">No</Badge>;
  if (type === "date" && typeof value === "string") return <>{formatDate(value)}</>;
  if (type === "datetime" && typeof value === "string") return <>{formatDatetime(value)}</>;
  if (type === "currency" && typeof value === "number") return <Currency amount={value} />;
  if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) {
    return (
      <span className="inline-flex items-center gap-1">
        <span className="w-3 h-3 rounded-sm border inline-block" style={{ background: value }} />
        <code className="text-[10px]">{value}</code>
      </span>
    );
  }
  if (typeof value === "number" && Math.abs(value) >= 100) return <Currency amount={value} />;
  return <>{String(value)}</>;
}
