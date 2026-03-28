import { useState } from "react";
import { Pin, X, MessageCircle } from "lucide-react";
import { crud } from "@/lib/api";
import { log } from "@/lib/log";
import { Currency } from "@/components/sdui/Currency";
import { Badge } from "@/components/ui/badge";
import { useT } from "@/lib/i18n";
import type { CardMessage, PinnedCard, ViewTemplate } from "@/lib/store";
import { useStore } from "@/lib/store";
import {
  fieldKey,
  fieldLabel,
  fieldType,
  formatDate,
  formatDatetime,
  getCompactDisplayName,
  resolveFieldLabel,
} from "@/lib/utils";

async function reloadPin(pin: PinnedCard, updatePinData: (id: string, data: Record<string, unknown>) => void) {
  const res = await crud("get", pin.uri);
  const row = Array.isArray(res?.data) ? res.data[0] : res?.data;
  if (row) {
    if (res.actions) row.actions = res.actions;
    updatePinData(pin.id, row);
  }
}

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
  const compactKeys = view?.template?.compact?.fields?.map(fieldKey);
  const name = getCompactDisplayName(data, compactKeys);

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
        {tpl ? <TemplateBody data={data} tpl={tpl} view={view} t={t} /> : <FallbackBody data={data} />}
      </div>

      {pin.messages.length > 0 && <CardMessages messages={pin.messages} pin={pin} t={t} />}

      <CardActions pin={pin} data={data} view={view} t={t} />
    </div>
  );
}

function CardMessages({ messages, pin, t }: { messages: CardMessage[]; pin: PinnedCard; t: (k: string) => string }) {
  const showToast = useStore((s) => s.showToast);
  const updatePinData = useStore((s) => s.updatePinData);

  async function execAction(action: { label: string; verb: string; uri: string; data?: Record<string, unknown> }) {
    try {
      log("card", "exec action", action);
      await crud(action.verb, action.uri, action.data);
      await reloadPin(pin, updatePinData);
      showToast({ msg: action.label, level: "success" });
    } catch (err: unknown) {
      showToast({ msg: err instanceof Error ? err.message : "Error", level: "error" });
    }
  }

  return (
    <div className="border-t">
      {messages.map((m, i) => (
        <div key={i} className="px-4 py-2 flex flex-col gap-1.5 border-b last:border-b-0 bg-muted/30">
          <div className="flex items-start gap-2">
            <MessageCircle className="w-3 h-3 mt-0.5 text-primary shrink-0" />
            <p className="text-xs text-foreground">{m.msg}</p>
          </div>
          {m.actions && m.actions.length > 0 && (
            <div className="flex gap-1.5 flex-wrap pl-5">
              {m.actions.map((a, j) => (
                <button
                  key={j}
                  onClick={() => execAction(a)}
                  className="px-2 py-0.5 text-[11px] bg-primary/10 text-primary rounded hover:bg-primary/20 transition-colors"
                >
                  {a.label}
                </button>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

function TemplateBody({
  data,
  tpl,
  view,
  t,
}: {
  data: Record<string, unknown>;
  tpl: NonNullable<NonNullable<ViewTemplate["template"]>["standard"]>;
  view: ViewTemplate | null;
  t: (key: string) => string;
}) {
  return (
    <>
      <div className="flex flex-col gap-1">
        {tpl.fields.map((f) => {
          const k = fieldKey(f);
          const val = data[k];
          if (val == null || val === "") return null;
          const ft = fieldType(f);
          const fl = fieldLabel(f);
          const label = fl ? t(fl) : resolveFieldLabel(k, view?.uri, view?.template?.form?.sections, t);
          return (
            <div key={k} className="flex justify-between gap-2">
              <span className="text-muted-foreground text-xs">{label}</span>
              <span className="text-xs text-right truncate max-w-[60%]">
                <FieldValue value={val} type={ft} />
              </span>
            </div>
          );
        })}
      </div>

      {tpl.stats && tpl.stats.length > 0 && (
        <div className="flex gap-3 pt-2 border-t mt-1">
          {tpl.stats.map((stat) => (
            <div key={stat.key} className="flex flex-col gap-0.5">
              <span
                className={`text-base font-bold ${stat.variant === "warning" ? "text-amber-600" : "text-foreground"}`}
              >
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
            <Badge
              key={rel.entity}
              variant="outline"
              className="text-[10px] font-normal cursor-pointer hover:bg-accent"
            >
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
            <span className="text-xs text-right truncate max-w-[60%]">{val == null ? "—" : String(val)}</span>
          </div>
        ))}
    </>
  );
}

function FieldValue({ value, type }: { value: unknown; type?: string }) {
  if (value === true)
    return (
      <Badge variant="default" className="text-[10px]">
        Yes
      </Badge>
    );
  if (value === false)
    return (
      <Badge variant="secondary" className="text-[10px]">
        No
      </Badge>
    );
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
  if (typeof value === "number" && Math.abs(value) >= 100) {
    return <Currency amount={value} />;
  }
  return <>{String(value)}</>;
}

function CardActions({
  pin,
  data,
  view,
  t,
}: {
  pin: PinnedCard;
  data: Record<string, unknown>;
  view: ViewTemplate | null;
  t: (key: string) => string;
}) {
  const hateoas = data.actions as Array<{ method: string; uri: string }> | undefined;
  if (!hateoas || hateoas.length === 0) return null;

  const catalog = view?.actions ?? {};
  const showToast = useStore((s) => s.showToast);
  const unpin = useStore((s) => s.unpin);
  const updatePinData = useStore((s) => s.updatePinData);
  const [pending, setPending] = useState<{ method: string; uri: string } | null>(null);
  const [loading, setLoading] = useState(false);

  const pendingMeta = pending ? catalog[pending.method] : null;

  async function exec(action: { method: string; uri: string }) {
    setLoading(true);
    try {
      await crud("post", action.uri);
      if (action.method === "delete") {
        unpin(pin.id);
      } else {
        await reloadPin(pin, updatePinData);
      }
      showToast({ level: "success", msg: t(catalog[action.method]?.label ?? action.method) });
    } catch (err: unknown) {
      showToast({ msg: err instanceof Error ? err.message : "Error", level: "error" });
    } finally {
      setLoading(false);
      setPending(null);
    }
  }

  function handleClick(action: { method: string; uri: string }) {
    const meta = catalog[action.method];
    if (meta?.confirm) {
      setPending(action);
    } else {
      exec(action);
    }
  }

  if (pending) {
    return (
      <div className="px-4 py-3 border-t bg-muted/50">
        <p className="text-xs text-muted-foreground mb-2">{t(pendingMeta!.confirm!)}</p>
        <div className="flex gap-2">
          <button
            onClick={() => exec(pending)}
            disabled={loading}
            className={`px-3 py-1 text-xs rounded-md transition-colors ${
              pendingMeta?.variant === "danger"
                ? "bg-destructive text-destructive-foreground"
                : "bg-primary text-primary-foreground"
            }`}
          >
            {loading ? "..." : t(pendingMeta!.label)}
          </button>
          <button
            onClick={() => setPending(null)}
            disabled={loading}
            className="px-3 py-1 text-xs border rounded-md hover:bg-accent"
          >
            Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="px-4 py-2 border-t flex gap-2 flex-wrap">
      {hateoas.map((action) => {
        const meta = catalog[action.method];
        const label = meta?.label ? t(meta.label) : action.method;
        const styles = actionVariantStyles[meta?.variant ?? ""] ?? "hover:bg-accent";

        return (
          <button
            key={action.method}
            onClick={() => handleClick(action)}
            className={`px-2.5 py-1 text-xs border rounded-md transition-colors ${styles}`}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
