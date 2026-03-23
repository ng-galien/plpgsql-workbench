import { supabase } from "./supabase";
import { useStore } from "./store";

/** Subscribe to AI broadcast channel — toasts + navigation from MCP */
export function initRealtime() {
  const channel = supabase.channel("ai-activity");

  channel.on("broadcast", { event: "activity" }, (msg) => {
    const p = msg.payload as {
      msg?: string;
      detail?: string;
      href?: string;
      level?: string;
      action?: string;
    };

    if (p.action === "navigate" && p.href) {
      window.location.href = p.href;
    } else if (p.msg) {
      useStore.getState().showToast({
        msg: p.msg,
        level: p.level || "info",
        detail: p.detail,
        href: p.href,
      });
    }
  });

  channel.subscribe();

  return () => channel.unsubscribe();
}
