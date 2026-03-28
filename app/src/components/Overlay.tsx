import { ArrowLeft, Pin } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { crud, get } from "@/lib/api";
import { useT } from "@/lib/i18n";
import type { FormField, FormSection, ViewTemplate } from "@/lib/store";
import { useStore } from "@/lib/store";
import { fieldKey, getCompactDisplayName, parseEntityUri } from "@/lib/utils";

export function Overlay() {
  const overlay = useStore((s) => s.overlay);
  const closeOverlay = useStore((s) => s.closeOverlay);
  const pin = useStore((s) => s.pin);
  const t = useT();

  if (!overlay.open || !overlay.entityUri) return null;

  return (
    <>
      <div className="absolute inset-0 bg-black/5 z-10" onClick={closeOverlay} />
      <div
        className="absolute left-0 top-0 h-full w-96 bg-card shadow-xl border-r z-20 flex flex-col animate-in slide-in-from-left duration-200"
        data-debug={`overlay[${overlay.entityUri}]`}
      >
        <OverlayContent
          entityUri={overlay.entityUri}
          onPin={(uri, data, view) => {
            pin({
              uri,
              entityUri: overlay.entityUri!,
              entityId: String(data.id ?? data.slug ?? ""),
              data,
              view: view ?? null,
              level: "standard",
            });
          }}
          onClose={closeOverlay}
          t={t}
        />
      </div>
    </>
  );
}

function OverlayContent({
  entityUri,
  onPin,
  onClose,
  t,
}: {
  entityUri: string;
  onPin: (uri: string, data: Record<string, unknown>, view?: ViewTemplate | null) => void;
  onClose: () => void;
  t: (key: string) => string;
}) {
  const [mode, setMode] = useState<"list" | "create">("list");
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const view = useStore((s) => s.getView(entityUri));

  useEffect(() => {
    setLoading(true);
    setError(null);
    get(entityUri)
      .then((res) => {
        setRows(res?.data ?? []);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [entityUri]);

  const { schema, entity } = parseEntityUri(entityUri);

  if (mode === "create" && view?.template?.form) {
    return (
      <OverlayForm
        entityUri={entityUri}
        form={view.template.form}
        schema={schema}
        entity={entity}
        onCreated={(newRow) => {
          setRows((prev) => [newRow, ...prev]);
          setMode("list");
          onPin(`${entityUri}/${newRow.id ?? newRow.slug ?? ""}`, newRow, view);
        }}
        onBack={() => setMode("list")}
        t={t}
      />
    );
  }

  return (
    <OverlayList
      entityUri={entityUri}
      rows={rows}
      view={view}
      loading={loading}
      error={error}
      schema={schema}
      entity={entity}
      onPin={onPin}
      onClose={onClose}
      onCreate={() => setMode("create")}
      t={t}
    />
  );
}

// --- List mode ---

function OverlayList({
  entityUri,
  rows,
  view,
  loading,
  error,
  schema,
  entity,
  onPin,
  onClose,
  onCreate,
  t,
}: {
  entityUri: string;
  rows: Record<string, unknown>[];
  view: ViewTemplate | null;
  loading: boolean;
  error: string | null;
  schema: string;
  entity: string;
  onPin: (uri: string, data: Record<string, unknown>, view?: ViewTemplate | null) => void;
  onClose: () => void;
  onCreate: () => void;
  t: (key: string) => string;
}) {
  const pinnedUris = useStore((s) => s.pins);
  const pinnedSet = useMemo(() => new Set(pinnedUris.map((p) => p.uri)), [pinnedUris]);
  const [search, setSearch] = useState("");

  const compactFields = useMemo(() => view?.template?.compact?.fields?.map(fieldKey), [view]);

  const filtered = search
    ? rows.filter((r) => getCompactDisplayName(r, compactFields, "").toLowerCase().includes(search.toLowerCase()))
    : rows;

  return (
    <>
      <div className="px-4 pt-4 pb-3 border-b flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-base">{t(`${schema}.entity_${entity}`)}</h2>
          <div className="flex items-center gap-2">
            <button
              onClick={onCreate}
              className="px-2.5 py-1 text-xs font-medium bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors"
            >
              + {t("app.new")}
            </button>
            <button onClick={onClose} className="text-muted-foreground hover:text-foreground text-lg leading-none">
              ×
            </button>
          </div>
        </div>

        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={t("app.search")}
          className="w-full px-3 py-1.5 bg-muted rounded-md text-sm border-none outline-none placeholder:text-muted-foreground"
          autoFocus
        />
      </div>

      <div className="flex-1 overflow-auto p-2 flex flex-col gap-1">
        {loading ? (
          <span className="text-xs text-muted-foreground px-3 py-2">Loading...</span>
        ) : error ? (
          <span className="text-xs text-destructive px-3 py-2">{error}</span>
        ) : filtered.length === 0 ? (
          <span className="text-xs text-muted-foreground px-3 py-2">No results.</span>
        ) : (
          filtered.map((row) => {
            const id = String(row.slug ?? row.id ?? "");
            const itemUri = `${entityUri}/${id}`;
            const name = getCompactDisplayName(row, compactFields);
            const subtitle = compactFields
              ? compactFields
                  .slice(1)
                  .filter((f) => row[f] != null)
                  .map((f) => String(row[f]))
                  .join(" · ")
              : [row.type, row.city, row.status, row.category].filter(Boolean).join(" · ");
            const isPinned = pinnedSet.has(itemUri);

            return (
              <div
                key={id}
                data-debug={`overlay.item[${itemUri}]`}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-md cursor-pointer transition-colors group ${
                  isPinned ? "bg-primary/5" : "hover:bg-accent"
                }`}
                onClick={() => {
                  if (!isPinned) onPin(itemUri, row, view);
                }}
              >
                <div
                  className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold shrink-0 ${
                    isPinned ? "bg-primary/20 text-primary" : "bg-primary/10 text-primary"
                  }`}
                >
                  {name.slice(0, 2).toUpperCase()}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{name}</div>
                  {subtitle && <div className="text-xs text-muted-foreground truncate">{subtitle}</div>}
                </div>

                <Pin
                  className={`w-3.5 h-3.5 ${
                    isPinned
                      ? "text-primary opacity-100 fill-primary"
                      : "text-muted-foreground opacity-0 group-hover:opacity-100"
                  } transition-opacity`}
                />
              </div>
            );
          })
        )}
      </div>
    </>
  );
}

// --- Create mode ---

function OverlayForm({
  entityUri,
  form,
  schema,
  entity,
  onCreated,
  onBack,
  t,
}: {
  entityUri: string;
  form: { sections: FormSection[] };
  schema: string;
  entity: string;
  onCreated: (row: Record<string, unknown>) => void;
  onBack: () => void;
  t: (key: string) => string;
}) {
  const [values, setValues] = useState<Record<string, unknown>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const setValue = (key: string, value: unknown) => {
    setValues((prev) => ({ ...prev, [key]: value }));
  };

  const handleSubmit = async () => {
    setSaving(true);
    setError(null);
    const { data: res, error: err } = await crud("set", entityUri, values as Record<string, unknown>)
      .then((r) => ({ data: r, error: null }))
      .catch((e) => ({ data: null, error: e }));

    setSaving(false);
    if (err) {
      setError(err.message ?? String(err));
      return;
    }
    if (res?.data) {
      onCreated(res.data as Record<string, unknown>);
    } else {
      onBack();
    }
  };

  return (
    <>
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b flex items-center gap-3">
        <button onClick={onBack} className="text-muted-foreground hover:text-foreground">
          <ArrowLeft className="w-4 h-4" />
        </button>
        <h2 className="font-semibold text-base">
          {t("app.new")} {t(`${schema}.entity_${entity}`)}
        </h2>
      </div>

      {/* Form */}
      <div className="flex-1 overflow-auto p-4 flex flex-col gap-5">
        {form.sections.map((section, si) => (
          <div key={si} className="flex flex-col gap-3">
            <span className="text-[10px] text-muted-foreground uppercase tracking-widest font-semibold">
              {t(section.label)}
            </span>
            {section.fields.map((field) => (
              <FormFieldInput
                key={field.key}
                field={field}
                value={values[field.key]}
                onChange={(v) => setValue(field.key, v)}
                t={t}
              />
            ))}
          </div>
        ))}
      </div>

      {/* Footer */}
      {error && <div className="px-4 py-2 text-xs text-destructive">{error}</div>}
      <div className="px-4 py-3 border-t flex justify-end gap-2">
        <button onClick={onBack} className="px-3 py-1.5 text-xs text-muted-foreground hover:text-foreground">
          {t("app.cancel")}
        </button>
        <button
          onClick={handleSubmit}
          disabled={saving}
          className="px-4 py-1.5 text-xs font-medium bg-primary text-primary-foreground rounded-md hover:bg-primary/90 disabled:opacity-50 transition-colors"
        >
          {saving ? "..." : t("app.save")}
        </button>
      </div>
    </>
  );
}

// --- Field input renderer ---

function ComboboxField({
  field,
  value,
  onChange,
  label,
  inputClass,
}: {
  field: FormField;
  value: unknown;
  onChange: (v: unknown) => void;
  label: string;
  inputClass: string;
}) {
  const [search, setSearch] = useState("");
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  const displayKey = field.display ?? "name";
  const selectedLabel = rows.find((r) => String(r.id) === String(value))?.[displayKey];

  useEffect(() => {
    if (!field.source) return;
    setLoading(true);
    get(field.source)
      .then((res) => setRows(res?.data ?? []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [field.source]);

  const filtered = search
    ? rows.filter((r) => {
        const name = String(r[displayKey] ?? "");
        return name.toLowerCase().includes(search.toLowerCase());
      })
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
          onChange={(e) => {
            setSearch(e.target.value);
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
                <div
                  key={id}
                  className={`px-3 py-2 text-sm cursor-pointer transition-colors ${
                    isSelected ? "bg-primary/10 text-primary" : "hover:bg-accent"
                  }`}
                  onMouseDown={(e) => {
                    e.preventDefault();
                    onChange(id !== "" && !Number.isNaN(Number(id)) ? Number(id) : id);
                    setSearch("");
                    setOpen(false);
                  }}
                >
                  {name}
                </div>
              );
            })
          )}
        </div>
      )}
    </label>
  );
}

function FormFieldInput({
  field,
  value,
  onChange,
  t,
}: {
  field: FormField;
  value: unknown;
  onChange: (v: unknown) => void;
  t: (key: string) => string;
}) {
  const label = t(field.label);
  const inputClass = "w-full px-3 py-1.5 bg-muted rounded-md text-sm border-none outline-none";

  switch (field.type) {
    case "select": {
      const raw = field.options;
      const options: Array<{ value: string; label: string } | string> = Array.isArray(raw) ? raw : [];
      return (
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted-foreground">
            {label}
            {field.required && <span className="text-destructive ml-0.5">*</span>}
          </span>
          <select value={String(value ?? "")} onChange={(e) => onChange(e.target.value)} className={inputClass}>
            <option value="">—</option>
            {options.map((opt) => {
              const optValue = typeof opt === "string" ? opt : opt.value;
              const optLabel = typeof opt === "string" ? opt : t(opt.label);
              return (
                <option key={optValue} value={optValue}>
                  {optLabel}
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
            onChange={(e) => onChange(e.target.value)}
            className={`${inputClass} resize-none`}
            rows={3}
          />
        </label>
      );

    case "combobox":
      return <ComboboxField field={field} value={value} onChange={onChange} label={label} inputClass={inputClass} />;

    case "checkbox":
      return (
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={!!value} onChange={(e) => onChange(e.target.checked)} className="rounded" />
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
            onChange={(e) => onChange(field.type === "number" ? Number(e.target.value) : e.target.value)}
            className={inputClass}
            required={field.required}
          />
        </label>
      );
  }
}
