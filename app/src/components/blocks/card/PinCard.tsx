import { X } from "lucide-react";
import { useState } from "react";
import { SduiRenderer } from "@/components/sdui/SduiRenderer";
import { crud } from "@/lib/api";
import { useT } from "@/lib/i18n";
import type { SduiActionNode } from "@/lib/sdui";
import { getSduiActions, getSduiRoot } from "@/lib/sdui";
import type { PinnedCard } from "@/lib/store";
import { useStore } from "@/lib/store";
import { fieldKey, getCompactDisplayName } from "@/lib/utils";
import { FallbackBody } from "./CardBody";
import { CardMessages } from "./CardMessages";
import { reloadPin } from "./reloadPin";

export function PinCard({ pin, onClose }: { pin: PinnedCard; onClose: () => void }) {
  const t = useT();
  const showToast = useStore((s) => s.showToast);
  const updatePinData = useStore((s) => s.updatePinData);
  const unpin = useStore((s) => s.unpin);
  const [confirmingAction, setConfirmingAction] = useState<SduiActionNode | null>(null);
  const data = pin.data;
  if (!data) return null;

  const view = pin.view;
  const compactKeys = view?.template?.compact?.fields?.map(fieldKey);
  const name = getCompactDisplayName(data, compactKeys);
  const sduiRoot = getSduiRoot(data, view, pin.level);
  const actions = getSduiActions(view, data);

  async function execAction(action: SduiActionNode) {
    try {
      await crud(action.verb, action.uri);
      if (action.verb === "delete") {
        unpin(pin.id);
      } else {
        await reloadPin(pin, updatePinData);
      }
      showToast({ level: "success", msg: t(action.label) });
    } catch (err: unknown) {
      showToast({ msg: err instanceof Error ? err.message : "Error", level: "error" });
    } finally {
      setConfirmingAction(null);
    }
  }

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
        {sduiRoot ? (
          <SduiRenderer
            node={sduiRoot}
            data={data}
            parentUri={pin.uri}
            t={t}
            onAction={(action) => {
              if (action.confirm) {
                setConfirmingAction(action);
                return;
              }
              return execAction(action);
            }}
          />
        ) : (
          <FallbackBody data={data} />
        )}
      </div>

      {pin.messages.length > 0 && <CardMessages messages={pin.messages} pin={pin} />}

      {confirmingAction && (
        <div className="px-4 py-3 border-t bg-muted/50">
          <p className="text-xs text-muted-foreground mb-2">
            {confirmingAction.confirm ? t(confirmingAction.confirm) : "Confirm"}
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => {
                void execAction(confirmingAction);
              }}
              className={`px-3 py-1 text-xs rounded-md transition-colors ${
                confirmingAction.variant === "danger"
                  ? "bg-destructive text-destructive-foreground"
                  : "bg-primary text-primary-foreground"
              }`}
            >
              {t(confirmingAction.label)}
            </button>
            <button
              onClick={() => setConfirmingAction(null)}
              className="px-3 py-1 text-xs border rounded-md hover:bg-accent"
            >
              {t("app.cancel")}
            </button>
          </div>
        </div>
      )}

      {!confirmingAction && actions.length > 0 && (
        <div className="px-4 py-2 border-t flex gap-2 flex-wrap">
          {actions.map((action) => (
            <SduiRenderer
              key={`${action.verb}:${action.uri}`}
              node={action}
              data={data}
              parentUri={pin.uri}
              t={t}
              onAction={(nextAction) => {
                if (nextAction.confirm) {
                  setConfirmingAction(nextAction);
                  return;
                }
                return execAction(nextAction);
              }}
            />
          ))}
        </div>
      )}
    </div>
  );
}
