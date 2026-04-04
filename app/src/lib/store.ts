import { create } from "zustand";
import { get as apiGet } from "./api";
import type {
  SduiFormField as FormField,
  SduiFormSection as FormSection,
  SduiViewField as ViewField,
  SduiViewTemplate as ViewTemplate,
} from "./generated/sdui-contract";
import { sdui, supabase } from "./supabase";

// --- Types ---

export type ToastLevel = "success" | "error" | "warning" | "info";

export interface NavItem {
  href?: string;
  label?: string;
  icon?: string;
  entity?: string;
  uri?: string;
}

export interface Module {
  module: string;
  brand: string;
  schema: string;
  group?: string;
  items: NavItem[];
}

export interface Toast {
  msg: string;
  level: ToastLevel;
  detail?: string;
  href?: string;
  timeout?: number;
}

export type { FormField, FormSection, ViewField, ViewTemplate };

export interface CardAction {
  id: string;
  label: string;
  verb: string;
  uri: string;
  data?: Record<string, unknown>;
}

export interface CardMessage {
  id: string;
  from: string;
  msg: string;
  actions?: CardAction[];
  at: number;
}

export interface PinnedCard {
  id: string;
  uri: string;
  entityUri: string;
  entityId: string;
  data: Record<string, unknown> | null;
  view: ViewTemplate | null;
  level: "compact" | "standard" | "expanded";
  position: { x: number; y: number };
  messages: CardMessage[];
}

export interface OverlayState {
  open: boolean;
  entityUri: string | null;
}

// --- Store ---

type View = "workspace" | "admin";

interface AppState {
  view: View;
  setView: (v: View) => void;

  modules: Module[];
  loading: boolean;
  loadModules: () => Promise<void>;
  loadViews: () => Promise<void>;
  getView: (entityUri: string) => ViewTemplate | null;

  toast: Toast | null;
  showToast: (toast: Toast) => void;
  clearToast: () => void;

  viewCache: Record<string, ViewTemplate>;
  pins: PinnedCard[];
  _pinCounter: number;
  pin: (card: Omit<PinnedCard, "id" | "position" | "messages">) => string;
  unpin: (id: string) => void;
  movePin: (id: string, position: { x: number; y: number }) => void;
  setPinLevel: (id: string, level: PinnedCard["level"]) => void;
  updatePinData: (id: string, data: Record<string, unknown>) => void;
  pushMessage: (uri: string, message: CardMessage) => void;
  removeAction: (uri: string, actionId: string) => void;

  overlay: OverlayState;
  openOverlay: (entityUri: string) => void;
  closeOverlay: () => void;
}

let toastTimer: ReturnType<typeof setTimeout> | null = null;

export const useStore = create<AppState>((set, get) => ({
  view: "workspace" as View,
  setView: (v) => set({ view: v }),

  modules: [],
  loading: true,
  loadModules: async () => {
    const { data } = await sdui.rpc("app_nav");
    set({ modules: data ?? [], loading: false });
  },
  loadViews: async () => {
    const modules = get().modules;
    const entities: { schema: string; entity: string; uri: string }[] = [];
    for (const m of modules) {
      for (const item of m.items ?? []) {
        if (item.entity) {
          entities.push({ schema: m.schema, entity: item.entity, uri: item.uri || `${m.schema}://${item.entity}` });
        }
      }
    }
    const results = await Promise.allSettled(
      entities.map(async (e) => {
        const { data } = await supabase.schema(e.schema).rpc(`${e.entity}_view`);
        return { uri: e.uri, view: data as ViewTemplate };
      }),
    );
    const cache: Record<string, ViewTemplate> = {};
    for (const r of results) {
      if (r.status === "fulfilled" && r.value.view) {
        cache[r.value.uri] = r.value.view;
      }
    }
    set({ viewCache: cache });
  },
  getView: (entityUri) => get().viewCache[entityUri] ?? null,

  toast: null,
  showToast: (toast) => {
    if (toastTimer) clearTimeout(toastTimer);
    set({ toast });
    if (!toast.href) {
      toastTimer = setTimeout(
        () => {
          set({ toast: null });
          toastTimer = null;
        },
        toast.timeout ?? (toast.level === "error" ? 8000 : 3000),
      );
    }
  },
  clearToast: () => {
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = null;
    set({ toast: null });
  },

  viewCache: {},
  _pinCounter: 0,
  pins: [],

  pin: (card) => {
    if (get().pins.some((p) => p.uri === card.uri)) return card.uri;

    const counter = get()._pinCounter + 1;
    const id = `pin-${counter}`;
    const offset = get().pins.length;
    const position = { x: 20 + offset * 30, y: 20 + offset * 20 };
    const view = card.view ?? get().viewCache[card.entityUri] ?? null;

    set((s) => ({
      _pinCounter: counter,
      pins: [...s.pins, { ...card, id, position, view, messages: [] }],
    }));

    if (!card.data) {
      apiGet(card.uri)
        .then((res) => {
          if (!res) return;
          const fullData = res.data as Record<string, unknown> | null;
          if (fullData) {
            const actions = res.actions as unknown[] | undefined;
            const enriched = actions?.length ? { ...fullData, actions } : fullData;
            set((s) => ({
              pins: s.pins.map((p) => (p.id === id ? { ...p, data: enriched } : p)),
            }));
          }
        })
        .catch(() => {});
    }

    return card.uri;
  },

  unpin: (id) => set((s) => ({ pins: s.pins.filter((p) => p.id !== id) })),

  movePin: (id, position) =>
    set((s) => ({
      pins: s.pins.map((p) => (p.id === id ? { ...p, position } : p)),
    })),

  setPinLevel: (id, level) =>
    set((s) => ({
      pins: s.pins.map((p) => (p.id === id ? { ...p, level } : p)),
    })),

  updatePinData: (id, data) =>
    set((s) => ({
      pins: s.pins.map((p) => (p.id === id ? { ...p, data } : p)),
    })),

  pushMessage: (uri, message) =>
    set((s) => ({
      pins: s.pins.map((p) => (p.uri === uri ? { ...p, messages: [...p.messages, message].slice(-50) } : p)),
    })),

  removeAction: (uri, actionId) =>
    set((s) => ({
      pins: s.pins.map((p) => {
        if (p.uri !== uri) return p;
        const messages = p.messages
          .map((m) => {
            if (!m.actions?.some((a) => a.id === actionId)) return m;
            const filtered = m.actions.filter((a) => a.id !== actionId);
            return filtered.length === 0 ? null : { ...m, actions: filtered };
          })
          .filter((m): m is CardMessage => m !== null);
        return { ...p, messages };
      }),
    })),

  overlay: { open: false, entityUri: null },

  openOverlay: (entityUri) => set({ overlay: { open: true, entityUri } }),

  closeOverlay: () => set({ overlay: { open: false, entityUri: null } }),
}));
