/** i18n — key-based translation with JSON dictionary */

let dict: Record<string, string> = {};

export function t(key: string): string {
  return dict[key] || key;
}

export async function loadI18n(lang: string = "fr"): Promise<void> {
  try {
    const r = await fetch(`/i18n/${lang}.json`);
    if (r.ok) dict = await r.json();
    else console.warn(`[i18n] ${lang}.json: HTTP ${r.status}`);
  } catch (err) {
    console.warn("[i18n] failed to load dictionary, falling back to keys", err);
  }
}
