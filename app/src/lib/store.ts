import { create } from "zustand";
import { supabase } from "./supabase";

interface Module {
  module: string;
  brand: string;
  schema: string;
  items: { href?: string; label?: string; icon?: string }[];
}

interface Toast {
  msg: string;
  level: string;
  detail?: string;
  href?: string;
}

interface AppState {
  modules: Module[];
  toast: Toast | null;
  loading: boolean;

  // Actions
  loadModules: () => Promise<void>;
  showToast: (toast: Toast) => void;
  clearToast: () => void;
}

export const useStore = create<AppState>((set) => ({
  modules: [],
  toast: null,
  loading: true,

  loadModules: async () => {
    const { data } = await supabase.schema("pgv").rpc("app_nav");
    set({ modules: data ?? [], loading: false });
  },

  showToast: (toast) => {
    set({ toast });
    if (!toast.href) {
      setTimeout(() => set({ toast: null }), toast.level === "error" ? 8000 : 3000);
    }
  },

  clearToast: () => set({ toast: null }),
}));
