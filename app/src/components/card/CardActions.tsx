import { useState } from "react";
import { crud } from "@/lib/api";
import type { PinnedCard, ViewTemplate } from "@/lib/store";
import { useStore } from "@/lib/store";
import { reloadPin } from "./reloadPin";

const variantStyles: Record<string, string> = {
  danger: "border-destructive/30 text-destructive hover:bg-destructive/10",
  warning: "border-amber-300 text-amber-700 hover:bg-amber-50",
  primary: "border-primary/30 text-primary hover:bg-primary/10",
};

export function CardActions({
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
        const styles = variantStyles[meta?.variant ?? ""] ?? "hover:bg-accent";

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
