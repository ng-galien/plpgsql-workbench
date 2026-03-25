import { create } from "zustand";
import { get as apiGet } from "./api";
import { pgv } from "./supabase";

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
}

export type ViewField = string | { key: string; type?: string; label?: string };

export interface FormField {
  key: string;
  type: string;
  label: string;
  required?: boolean;
  options?: unknown;
  source?: string;
  display?: string;
  filter?: string;
}

export interface FormSection {
  label: string;
  fields: FormField[];
}

export interface ViewTemplate {
  uri?: string;
  label?: string;
  icon?: string;
  template?: {
    compact?: { fields: ViewField[] };
    standard?: {
      fields: ViewField[];
      stats?: { key: string; label: string; variant?: string }[];
      related?: { entity: string; label: string; filter: string }[];
    };
    expanded?: {
      fields: ViewField[];
      stats?: { key: string; label: string; variant?: string }[];
      related?: { entity: string; label: string; filter: string }[];
    };
    form?: {
      sections: FormSection[];
    };
  };
  actions?: Record<string, { label: string; icon?: string; variant?: string; confirm?: string }>;
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
}

export interface OverlayState {
  open: boolean;
  entityUri: string | null;
}

// --- Store ---

interface AppState {
  modules: Module[];
  loading: boolean;
  loadModules: () => Promise<void>;

  toast: Toast | null;
  showToast: (toast: Toast) => void;
  clearToast: () => void;

  viewCache: Record<string, ViewTemplate>;
  pins: PinnedCard[];
  _pinCounter: number;
  pin: (card: Omit<PinnedCard, "id" | "position">) => void;
  unpin: (id: string) => void;
  movePin: (id: string, position: { x: number; y: number }) => void;
  setPinLevel: (id: string, level: PinnedCard["level"]) => void;
  updatePinData: (id: string, data: Record<string, unknown>) => void;

  overlay: OverlayState;
  openOverlay: (entityUri: string) => void;
  closeOverlay: () => void;
}

let toastTimer: ReturnType<typeof setTimeout> | null = null;

export const useStore = create<AppState>((set, get) => ({
  modules: [],
  loading: true,
  loadModules: async () => {
    const { data } = await pgv.rpc("app_nav");
    set({ modules: data ?? [], loading: false });
  },

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
        toast.level === "error" ? 8000 : 3000,
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
    if (get().pins.some((p) => p.uri === card.uri)) return;

    const counter = get()._pinCounter + 1;
    const id = `pin-${counter}`;
    const offset = get().pins.length;
    const position = { x: 20 + offset * 30, y: 20 + offset * 20 };

    set((s) => ({
      _pinCounter: counter,
      pins: [...s.pins, { ...card, id, position }],
    }));

    // Use cached view template if available
    const cachedView = get().viewCache[card.entityUri];

    apiGet(card.uri)
      .then((res) => {
        if (!res) return;
        const fullData = res.data as Record<string, unknown> | null;
        const view = (res.view as ViewTemplate | null) ?? cachedView ?? null;

        if (view && card.entityUri && !cachedView) {
          set((s) => ({
            viewCache: { ...s.viewCache, [card.entityUri]: view },
          }));
        }

        if (fullData) {
          const actions = res.actions as unknown[] | undefined;
          const enriched = actions?.length ? { ...fullData, actions } : fullData;
          set((s) => ({
            pins: s.pins.map((p) => (p.id === id ? { ...p, data: enriched, view } : p)),
          }));
        }
      })
      .catch(() => {});
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

  overlay: { open: false, entityUri: null },

  openOverlay: (entityUri) => set({ overlay: { open: true, entityUri } }),

  closeOverlay: () => set({ overlay: { open: false, entityUri: null } }),
}));
