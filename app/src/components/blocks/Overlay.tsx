import { ArrowLeft, Pin } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { SduiRenderer } from "@/components/sdui/SduiRenderer";
import { crud, get } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { getSduiFormRoot, getSduiRoot } from "@/lib/sdui";
import type { ViewTemplate } from "@/lib/store";
import { useStore } from "@/lib/store";
import { fieldKey, getCompactDisplayName, parseEntityUri } from "@/lib/utils";

export function Overlay() {
  const overlay = useStore((s) => s.overlay);
  const closeOverlay = useStore((s) => s.closeOverlay);
  const pin = useStore((s) => s.pin);
  const t = useT();
  const overlayEntityUri = overlay.entityUri;

  if (!overlay.open || !overlayEntityUri) return null;

  return (
    <>
      <button
        type="button"
        className="absolute inset-0 bg-black/5 z-10"
        aria-label={t("app.cancel")}
        onClick={closeOverlay}
      />
      <div
        className="absolute left-0 top-0 h-full w-96 bg-card shadow-xl border-r z-20 flex flex-col animate-in slide-in-from-left duration-200"
        data-debug={`overlay[${overlayEntityUri}]`}
      >
        <OverlayContent
          entityUri={overlayEntityUri}
          onPin={(uri, data, view) => {
            pin({
              uri,
              entityUri: overlayEntityUri,
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
        schema={schema}
        entity={entity}
        view={view}
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
            const compactRoot = getSduiRoot(row, view, "compact");
            const subtitle = compactFields
              ? compactFields
                  .slice(1)
                  .filter((f) => row[f] != null)
                  .map((f) => String(row[f]))
                  .join(" · ")
              : [row.type, row.city, row.status, row.category].filter(Boolean).join(" · ");
            const isPinned = pinnedSet.has(itemUri);

            return (
              <button
                key={id}
                type="button"
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
                  {compactRoot ? (
                    <div className="text-left">
                      <SduiRenderer node={compactRoot} data={row} parentUri={itemUri} t={t} />
                    </div>
                  ) : (
                    <>
                      <div className="text-sm font-medium truncate">{name}</div>
                      {subtitle && <div className="text-xs text-muted-foreground truncate">{subtitle}</div>}
                    </>
                  )}
                </div>

                <Pin
                  className={`w-3.5 h-3.5 ${
                    isPinned
                      ? "text-primary opacity-100 fill-primary"
                      : "text-muted-foreground opacity-0 group-hover:opacity-100"
                  } transition-opacity`}
                />
              </button>
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
  schema,
  entity,
  view,
  onCreated,
  onBack,
  t,
}: {
  entityUri: string;
  schema: string;
  entity: string;
  view: ViewTemplate | null;
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
  const formNode = getSduiFormRoot(view);

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
        {formNode ? <SduiRenderer node={formNode} values={values} t={t} onFieldChange={setValue} /> : null}
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
