import { useEffect, useMemo, useState } from "react";
import { useStore } from "@/lib/store";
import { useT } from "@/lib/i18n";
import { get } from "@/lib/api";
import { getDisplayName, parseEntityUri } from "@/lib/utils";
import { Pin } from "lucide-react";

export function Overlay() {
  const overlay = useStore((s) => s.overlay);
  const closeOverlay = useStore((s) => s.closeOverlay);
  const pin = useStore((s) => s.pin);
  const t = useT();

  if (!overlay.open || !overlay.entityUri) return null;

  return (
    <>
      <div
        className="absolute inset-0 bg-black/5 z-10"
        onClick={closeOverlay}
      />
      <div className="absolute left-0 top-0 h-full w-96 bg-card shadow-xl border-r z-20 flex flex-col animate-in slide-in-from-left duration-200" data-debug={`overlay[${overlay.entityUri}]`}>
        <OverlayList
          entityUri={overlay.entityUri}
          onPin={(uri, data) => {
            pin({
              uri,
              entityUri: overlay.entityUri!,
              entityId: String(data.id ?? data.slug ?? ""),
              data,
              view: null,
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

function OverlayList({
  entityUri,
  onPin,
  onClose,
  t,
}: {
  entityUri: string;
  onPin: (uri: string, data: Record<string, unknown>) => void;
  onClose: () => void;
  t: (key: string) => string;
}) {
  const pinnedUris = useStore((s) => s.pins);
  const pinnedSet = useMemo(() => new Set(pinnedUris.map((p) => p.uri)), [pinnedUris]);

  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    setLoading(true);
    setError(null);
    get(entityUri)
      .then((res) => setRows(res?.data ?? []))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [entityUri]);

  const filtered = search
    ? rows.filter((r) =>
        getDisplayName(r, "").toLowerCase().includes(search.toLowerCase())
      )
    : rows;

  const { schema, entity } = parseEntityUri(entityUri);

  return (
    <>
      <div className="px-4 pt-4 pb-3 border-b flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-base">
            {t(`${schema}.entity_${entity}`)}
          </h2>
          <div className="flex items-center gap-2">
            <button
              onClick={() => {/* TODO: open create form */}}
              className="px-2.5 py-1 text-xs font-medium bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors"
            >
              + {t("app.new")}
            </button>
            <button
              onClick={onClose}
              className="text-muted-foreground hover:text-foreground text-lg leading-none"
            >
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
            const name = getDisplayName(row);
            const subtitle = [row.type, row.city, row.status, row.category]
              .filter(Boolean)
              .join(" · ");
            const isPinned = pinnedSet.has(itemUri);

            return (
              <div
                key={id}
                data-debug={`overlay.item[${itemUri}]`}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-md cursor-pointer transition-colors group ${
                  isPinned ? "bg-primary/5" : "hover:bg-accent"
                }`}
                onClick={() => {
                  if (!isPinned) onPin(itemUri, row);
                }}
              >
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold shrink-0 ${
                  isPinned ? "bg-primary/20 text-primary" : "bg-primary/10 text-primary"
                }`}>
                  {name.slice(0, 2).toUpperCase()}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{name}</div>
                  {subtitle && (
                    <div className="text-xs text-muted-foreground truncate">{subtitle}</div>
                  )}
                </div>

                <Pin className={`w-3.5 h-3.5 ${
                  isPinned
                    ? "text-primary opacity-100 fill-primary"
                    : "text-muted-foreground opacity-0 group-hover:opacity-100"
                } transition-opacity`} />
              </div>
            );
          })
        )}
      </div>
    </>
  );
}
