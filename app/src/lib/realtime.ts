import { crud } from "./api";
import { log } from "./log";
import type { CardMessage, ToastLevel } from "./store";
import { useStore } from "./store";
import { supabase } from "./supabase";

interface UIAction {
  action: string;
  uri?: string;
  entity_uri?: string;
  message?: string;
  level?: string;
  detail?: string;
  href?: string;
  data?: Record<string, unknown>;
  timeout?: number;
}

const validLevels = new Set<ToastLevel>(["success", "error", "warning", "info"]);

async function ensurePin(uri: string, entityUri: string): Promise<void> {
  const store = useStore.getState();
  if (store.pins.some((p) => p.uri === uri)) return;
  const res = await crud("get", uri);
  if (!res?.data) return;
  const data = Array.isArray(res.data) ? res.data[0] : res.data;
  if (!data) return;
  if (res.actions) data.actions = res.actions;
  const view = store.getView(entityUri);
  store.pin({ uri, entityUri, entityId: String(data.id ?? data.slug ?? ""), data, view, level: "standard" });
}

async function refreshPin(uri: string): Promise<void> {
  const store = useStore.getState();
  const target = store.pins.find((p) => p.uri === uri);
  if (!target) return;
  const res = await crud("get", uri);
  if (!res?.data) return;
  const row = Array.isArray(res.data) ? res.data[0] : res.data;
  if (row) {
    if (res.actions) row.actions = res.actions;
    store.updatePinData(target.id, row);
  }
}

function handleAction(payload: UIAction) {
  const store = useStore.getState();
  log("realtime", `handle:${payload.action}`, { uri: payload.uri, message: payload.message });

  switch (payload.action) {
    case "pin": {
      if (!payload.uri) break;
      const entityUri = payload.entity_uri ?? payload.uri.replace(/\/[^/]+$/, "");
      ensurePin(payload.uri, entityUri);
      break;
    }

    case "unpin":
      if (payload.uri) {
        const pin = store.pins.find((p) => p.uri === payload.uri);
        if (pin) store.unpin(pin.id);
      }
      break;

    case "toast":
      if (payload.message) {
        const level: ToastLevel = validLevels.has(payload.level as ToastLevel)
          ? (payload.level as ToastLevel)
          : "info";
        store.showToast({ msg: payload.message, level, detail: payload.detail, href: payload.href, timeout: payload.timeout });
      }
      break;

    case "overlay":
      if (payload.uri) store.openOverlay(payload.uri);
      break;

    case "navigate":
      if (payload.href) window.location.href = payload.href;
      break;

    case "message": {
      if (!payload.uri || !payload.message) break;
      const entityUri = payload.entity_uri ?? payload.uri.replace(/\/[^/]+$/, "");
      const msg: CardMessage = {
        from: typeof payload.data?.from === "string" ? payload.data.from : "agent",
        msg: payload.message,
        actions: Array.isArray(payload.data?.actions) ? payload.data.actions as CardMessage["actions"] : undefined,
        at: Date.now(),
      };
      ensurePin(payload.uri, entityUri).then(() => {
        store.pushMessage(payload.uri!, msg);
      });
      break;
    }

    case "update": {
      if (!payload.uri) break;
      const targetPin = store.pins.find((p) => p.uri === payload.uri);
      log("realtime", "update", { uri: payload.uri, pinFound: !!targetPin, hasData: !!payload.data, pins: store.pins.map((p) => p.uri) });
      if (targetPin && payload.data) {
        store.updatePinData(targetPin.id, payload.data);
      }
      break;
    }

    case "refresh":
      if (payload.uri) refreshPin(payload.uri);
      break;
  }
}

export function initRealtime() {
  const channel = supabase.channel("ui");

  channel.on("broadcast", { event: "action" }, (msg) => {
    log("realtime", "action", msg.payload);
    try {
      handleAction(msg.payload as UIAction);
    } catch (err) {
      console.error("[realtime] handleAction error:", err);
    }
  });

  channel.subscribe((status) => {
    log("realtime", "channel", status);
  });

  return () => channel.unsubscribe();
}
