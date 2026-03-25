import type { ToastLevel } from "./store";
import { useStore } from "./store";
import { supabase } from "./supabase";

const validLevels = new Set<ToastLevel>(["success", "error", "warning", "info"]);

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
      const level: ToastLevel = validLevels.has(p.level as ToastLevel) ? (p.level as ToastLevel) : "info";
      useStore.getState().showToast({
        msg: p.msg,
        level,
        detail: p.detail,
        href: p.href,
      });
    }
  });

  channel.subscribe();
  return () => channel.unsubscribe();
}
