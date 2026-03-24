import { useStore } from "@/lib/store";
import { useT } from "@/lib/i18n";
import { getDisplayName } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import type { PinnedCard, ViewTemplate } from "@/lib/store";
import { X, Pin } from "lucide-react";

const actionVariantStyles: Record<string, string> = {
  danger: "border-destructive/30 text-destructive hover:bg-destructive/10",
  warning: "border-amber-300 text-amber-700 hover:bg-amber-50",
  primary: "border-primary/30 text-primary hover:bg-primary/10",
};

export function Canvas() {
  const pins = useStore((s) => s.pins);
  const unpin = useStore((s) => s.unpin);

  if (pins.length === 0) {
    return (
      <div className="h-full flex items-center justify-center bg-muted/30">
        <div className="text-center text-muted-foreground">
          <Pin className="w-8 h-8 mx-auto mb-3 opacity-30" />
          <p className="text-lg font-medium mb-1">Workspace</p>
          <p className="text-sm">Select an item from the sidebar to pin it here.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full bg-muted/30 relative overflow-auto p-6">
      <div className="flex flex-wrap gap-4 items-start">
        {pins.map((pin) => (
          <PinCard key={pin.id} pin={pin} onClose={() => unpin(pin.id)} />
        ))}
      </div>
    </div>
  );
}

function PinCard({ pin, onClose }: { pin: PinnedCard; onClose: () => void }) {
  const t = useT();
  const data = pin.data;
  if (!data) return null;

  const view = pin.view;
  const tpl = view?.template?.standard;
  const name = getDisplayName(data);

  return (
    <div
      className="bg-card border rounded-lg shadow-sm w-80 flex flex-col overflow-hidden"
      data-debug={`canvas.pin[${pin.uri}]`}
    >
      <div className="px-4 py-3 border-b flex items-center gap-2">
        <span className="font-semibold text-sm truncate flex-1">{name}</span>
        <button onClick={onClose} className="text-muted-foreground hover:text-foreground">
          <X className="w-3.5 h-3.5" />
        </button>
      </div>

      <div className="px-4 py-3 text-sm flex flex-col gap-2">
        {tpl ? (
          <TemplateBody data={data} tpl={tpl} t={t} />
        ) : (
          <FallbackBody data={data} />
        )}
      </div>

      <CardActions data={data} view={view} t={t} />
    </div>
  );
}

function TemplateBody({
  data,
  tpl,
  t,
}: {
  data: Record<string, unknown>;
  tpl: NonNullable<NonNullable<ViewTemplate["template"]>["standard"]>;
  t: (key: string) => string;
}) {
  return (
    <>
      <div className="flex flex-col gap-1">
        {tpl.fields
          .filter((key) => data[key] != null && data[key] !== "")
          .map((key) => (
            <div key={key} className="flex justify-between gap-2">
              <span className="text-muted-foreground text-xs">{key}</span>
              <span className="text-xs text-right truncate max-w-[60%]">
                <FieldValue value={data[key]} />
              </span>
            </div>
          ))}
      </div>

      {tpl.stats && tpl.stats.length > 0 && (
        <div className="flex gap-3 pt-2 border-t mt-1">
          {tpl.stats.map((stat) => (
            <div key={stat.key} className="flex flex-col gap-0.5">
              <span className={`text-base font-bold ${stat.variant === "warning" ? "text-amber-600" : "text-foreground"}`}>
                {data[stat.key] != null ? String(data[stat.key]) : "—"}
              </span>
              <span className="text-[10px] text-muted-foreground">{t(stat.label)}</span>
            </div>
          ))}
        </div>
      )}

      {tpl.related && tpl.related.length > 0 && (
        <div className="flex gap-1.5 flex-wrap pt-2 border-t mt-1">
          {tpl.related.map((rel) => (
            <Badge key={rel.entity} variant="outline" className="text-[10px] font-normal cursor-pointer hover:bg-accent">
              {t(rel.label)}
            </Badge>
          ))}
        </div>
      )}
    </>
  );
}

function FallbackBody({ data }: { data: Record<string, unknown> }) {
  const hidden = new Set(["id", "tenant_id", "created_at", "updated_at", "actions"]);
  return (
    <>
      {Object.entries(data)
        .filter(([k]) => !hidden.has(k))
        .slice(0, 8)
        .map(([key, val]) => (
          <div key={key} className="flex justify-between gap-2">
            <span className="text-muted-foreground text-xs">{key}</span>
            <span className="text-xs text-right truncate max-w-[60%]">
              {val == null ? "—" : String(val)}
            </span>
          </div>
        ))}
    </>
  );
}

function FieldValue({ value }: { value: unknown }) {
  if (value === true) return <Badge variant="default" className="text-[10px]">Yes</Badge>;
  if (value === false) return <Badge variant="secondary" className="text-[10px]">No</Badge>;
  if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) {
    return (
      <span className="inline-flex items-center gap-1">
        <span className="w-3 h-3 rounded-sm border inline-block" style={{ background: value }} />
        <code className="text-[10px]">{value}</code>
      </span>
    );
  }
  return <>{String(value)}</>;
}

function CardActions({
  data,
  view,
  t,
}: {
  data: Record<string, unknown>;
  view: ViewTemplate | null;
  t: (key: string) => string;
}) {
  const hateoas = data.actions as Array<{ method: string; uri: string }> | undefined;
  if (!hateoas || hateoas.length === 0) return null;

  const catalog = view?.actions ?? {};

  return (
    <div className="px-4 py-2 border-t flex gap-2 flex-wrap">
      {hateoas.map((action, i) => {
        const meta = catalog[action.method];
        const label = meta?.label ? t(meta.label) : action.method;
        const styles = actionVariantStyles[meta?.variant ?? ""] ?? "hover:bg-accent";

        return (
          <button
            key={i}
            className={`px-2.5 py-1 text-xs border rounded-md transition-colors ${styles}`}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
