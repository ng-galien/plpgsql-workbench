import { MessageCircle, X } from "lucide-react";
import { crud } from "@/lib/api";
import { log } from "@/lib/log";
import type { CardAction, CardMessage, PinnedCard } from "@/lib/store";
import { useStore } from "@/lib/store";
import { reloadPin } from "./reloadPin";

export function CardMessages({ messages, pin }: { messages: CardMessage[]; pin: PinnedCard }) {
  const showToast = useStore((s) => s.showToast);
  const updatePinData = useStore((s) => s.updatePinData);
  const removeAction = useStore((s) => s.removeAction);

  async function execAction(action: CardAction) {
    try {
      log("card", "exec action", action);
      await crud(action.verb, action.uri, action.data);
      await reloadPin(pin, updatePinData);
      removeAction(pin.uri, action.id);
      showToast({ msg: action.label, level: "success" });
    } catch (err: unknown) {
      showToast({ msg: err instanceof Error ? err.message : "Error", level: "error" });
    }
  }

  return (
    <div className="border-t">
      {messages.map((m) => (
        <div key={m.id} className="px-4 py-2 flex flex-col gap-1.5 border-b last:border-b-0 bg-muted/30">
          <div className="flex items-start gap-2">
            <MessageCircle className="w-3 h-3 mt-0.5 text-primary shrink-0" />
            <p className="text-xs text-foreground">{m.msg}</p>
          </div>
          {m.actions && m.actions.length > 0 && (
            <div className="flex gap-1.5 flex-wrap pl-5">
              {m.actions.map((a) => (
                <span key={a.id} className="inline-flex items-center gap-0.5">
                  <button
                    onClick={() => execAction(a)}
                    className="px-2 py-0.5 text-[11px] bg-primary/10 text-primary rounded-l hover:bg-primary/20 transition-colors"
                  >
                    {a.label}
                  </button>
                  <button
                    onClick={() => removeAction(pin.uri, a.id)}
                    className="px-1 py-0.5 text-[11px] bg-muted text-muted-foreground rounded-r hover:bg-destructive/10 hover:text-destructive transition-colors"
                  >
                    <X className="w-2.5 h-2.5" />
                  </button>
                </span>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
