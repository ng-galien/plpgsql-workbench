/** Global type declarations for the pgView shell */

// Alpine.js (no official types for CDN usage)
interface AlpineStatic {
  data(name: string, factory: (...args: never[]) => Record<string, unknown>): void;
  initTree(el: HTMLElement): void;
  $data(el: HTMLElement): Record<string, unknown>;
}
declare const Alpine: AlpineStatic;

// marked.js (CDN global)
declare const marked: {
  parse(md: string): string;
};

// pgv plugin system (defined in pgv-modules.js inline script)
interface PgvGlobal {
  mount(el: HTMLElement): void;
  unmount(): void;
  plugin(fn: (Alpine: AlpineStatic) => void): void;
  _flushPlugins(): void;
  _loadDeps(deps: string[], cb: () => void): void;
}

// D3 (CDN global — only checked for existence, not used directly)
declare const d3: unknown;

// Extend Window
interface Window {
  __PGV_CONFIG__: import("./config.js").PgvConfig;
  pgv: PgvGlobal;
}
