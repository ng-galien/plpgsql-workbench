import { create } from "zustand";
import { pgv } from "./supabase";

interface I18nState {
  translations: Record<string, string>;
  lang: string;
  loaded: boolean;
  load: (lang?: string) => Promise<void>;
  t: (key: string) => string;
}

let loading = false;

export const useI18n = create<I18nState>((set, get) => ({
  translations: {},
  lang: "fr",
  loaded: false,

  load: async (lang = "fr") => {
    if (loading || get().loaded) return;
    loading = true;
    const { data } = await pgv.rpc("i18n_bundle", { p_lang: lang });
    set({ translations: data ?? {}, lang, loaded: true });
    loading = false;
  },

  t: (key: string) => get().translations[key] ?? key,
}));

export function useT() {
  return useI18n((s) => s.t);
}
