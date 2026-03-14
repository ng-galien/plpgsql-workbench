/**
 * shell.ts — Alpine component factory for the pgView shell
 *
 * Creates the 'pgview' Alpine data component. Thin coordinator that
 * delegates to router.ts, enhance.ts, and plugin modules.
 */

import { getConfig } from "./config.js";
import { setEnhanceContext } from "./enhance.js";
import { loadI18n, t } from "./i18n.js";
import { pgListen, pgRpc } from "./realtime.js";
import {
  go,
  handleError,
  initRouter,
  openFormDialog,
  post,
  type RouterState,
  render,
  submitFormDialog,
} from "./router.js";

/** Create and return the pgview Alpine data object */
export function createShellComponent(): Record<string, unknown> {
  return {
    toast: { show: false, msg: "", level: "success", detail: "" },
    dlg: { title: "", target: "" },
    search: { open: false, query: "", idx: 0 },
    issue: { open: false, desc: "", type: "bug" },
    _tt: null as any,
    _modules: [] as any[],
    _currentSchema: null as string | null,
    _fixedSchema: null as string | null,
    _errors: [] as any[],
    _actions: [] as any[],

    /* -- Delegated to pgv kernel -- */
    t: (key: string): string => t(key),
    pgListen: (schema: string, table: string, handler: any) => pgListen(schema, table, handler),
    pgRpc: (fn: string, params?: Record<string, unknown>, schema?: string) => pgRpc(fn, params, schema),

    /* -- Bootstrap -- */
    boot: function (this: any) {
      var self = this;

      // Proxy pattern: router reads/writes to _state,
      // but Alpine reactivity requires mutations on `self`.
      // Getters/setters keep them in sync.
      var stateProxy: RouterState = {
        get modules() {
          return self._modules;
        },
        set modules(v) {
          self._modules = v;
        },
        get currentSchema() {
          return self._currentSchema;
        },
        set currentSchema(v) {
          self._currentSchema = v;
        },
        get fixedSchema() {
          return self._fixedSchema;
        },
        set fixedSchema(v) {
          self._fixedSchema = v;
        },
        get errors() {
          return self._errors;
        },
        set errors(v) {
          self._errors = v;
        },
        get actions() {
          return self._actions;
        },
        set actions(v) {
          self._actions = v;
        },
      };

      initRouter(stateProxy, {
        showToast: (msg, level, detail) => {
          self.showToast(msg, level, detail);
        },
        nextTick: (fn) => {
          self.$nextTick(fn);
        },
      });

      setEnhanceContext({
        go: (path) => {
          self.go(path);
        },
        showToast: (msg, level, detail) => {
          self.showToast(msg, level, detail);
        },
        currentSchema: () => self._currentSchema,
        nextTick: (fn) => {
          self.$nextTick(fn);
        },
      });

      // Error tracking (circular buffer, max 20) — store refs for cleanup
      self._onError = (e: ErrorEvent) => {
        self._errors.push({ msg: e.message, src: e.filename, line: e.lineno, ts: Date.now() });
        if (self._errors.length > 20) self._errors.shift();
      };
      self._onRejection = (e: PromiseRejectionEvent) => {
        self._errors.push({ msg: String(e.reason), ts: Date.now() });
        if (self._errors.length > 20) self._errors.shift();
      };
      window.addEventListener("error", self._onError);
      window.addEventListener("unhandledrejection", self._onRejection);

      var saved = localStorage.getItem("pgv-theme");
      if (saved) document.documentElement.setAttribute("data-theme", saved);
      // App mode: <meta name="pgv-schema"> fixes the schema
      // Dev mode: no meta -> extract schema from URL /{schema}/path
      var meta = document.querySelector('meta[name="pgv-schema"]');
      this._fixedSchema = meta ? meta.getAttribute("content") : null;
      this._listen();

      // Load i18n before first navigation so t() returns translated strings
      var lang = document.documentElement.lang || "fr";
      var cfg = getConfig();
      loadI18n(lang).then(() => {
        // Multi-module: fetch app_nav before initial navigation
        if (!self._fixedSchema) {
          fetch(cfg.rpc("/app_nav"), {
            method: "POST",
            headers: cfg.headers("application/json", "pgv"),
            body: "{}",
          })
            .then((r) => (r.ok ? r.json() : []))
            .then((mods: any[]) => {
              self._modules = Array.isArray(mods) ? mods : [];
              if (self._modules.length > 0) document.documentElement.style.setProperty("--pgv-app-bar-h", "2.5rem");
              self.go(location.pathname + location.search || "/");
            })
            .catch(() => {
              self._modules = [];
              self.go(location.pathname + location.search || "/");
            });
        } else {
          self.go(location.pathname + location.search || "/");
        }
      });
      window.onpopstate = () => {
        self.go(location.pathname + location.search || "/", false);
      };
    },

    /* -- Event delegation on #app -- */
    _listen: function (this: any) {
      var app = document.getElementById("app")!;

      // Cmd+K / Ctrl+K -> toggle search overlay — store ref for cleanup
      this._onKeydown = (e: KeyboardEvent) => {
        if ((e.metaKey || e.ctrlKey) && e.key === "k") {
          e.preventDefault();
          if (this.search.open) this.searchClose();
          else this.searchOpen();
        }
      };
      document.addEventListener("keydown", this._onKeydown);

      app.addEventListener("click", (e: Event) => {
        // Internal links
        var a = (e.target as Element).closest('a[href^="/"]');
        if (a) {
          e.preventDefault();
          return this.go(a.getAttribute("href"));
        }

        // data-rpc buttons
        var btn = (e.target as Element).closest("button[data-rpc]") as HTMLElement | null;
        if (btn) {
          e.preventDefault();
          const params = btn.dataset.params ? JSON.parse(btn.dataset.params) : {};
          if (btn.dataset.confirm) {
            this._confirm(btn.dataset.confirm).then((ok: boolean) => {
              if (ok) this.post(btn!.dataset.rpc, params);
            });
            return;
          }
          return this.post(btn.dataset.rpc, params);
        }

        // Theme toggle
        var thm = (e.target as Element).closest("[data-toggle-theme]");
        if (thm) {
          e.preventDefault();
          return this._themeToggle();
        }

        // data-dialog buttons
        var dlg = (e.target as Element).closest("[data-dialog]") as HTMLElement | null;
        if (dlg) {
          e.preventDefault();
          return this.openDialog(dlg.dataset.dialog, dlg.dataset.src, dlg.dataset.target);
        }

        // data-form-dialog buttons (open modal form)
        var fd = (e.target as Element).closest("[data-form-dialog]") as HTMLElement | null;
        if (fd) {
          e.preventDefault();
          return this.openFormDialog(fd.dataset.formDialog, fd.dataset.src);
        }
      });

      app.addEventListener("submit", (e: Event) => {
        var form = (e.target as Element).closest("form[data-rpc]") as HTMLFormElement | null;
        if (form) {
          e.preventDefault();
          const data: Record<string, unknown> = {};
          new FormData(form).forEach((v, k) => {
            data[k] = v;
          });
          if (form.hasAttribute("data-dialog-form")) {
            this.submitFormDialog(form, data);
          } else {
            this.post(form.dataset.rpc, data);
          }
          return;
        }
        // Filter forms: GET with query params -> SPA navigation
        var filter = (e.target as Element).closest("form[data-filter]") as HTMLFormElement | null;
        if (filter) {
          e.preventDefault();
          const parts: string[] = [];
          new FormData(filter).forEach((v, k) => {
            if (v !== "") parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(v as string)}`);
          });
          const qs = parts.join("&");
          this.go(location.pathname + (qs ? `?${qs}` : ""));
        }
      });

      // Dialog folder navigation — defer to $nextTick in case dlgBody is conditional
      this.$nextTick(() => {
        if (this.$refs.dlgBody) {
          this.$refs.dlgBody.addEventListener("click", (e: Event) => {
            var a = (e.target as Element).closest("a[data-path]") as HTMLElement | null;
            if (!a) return;
            e.preventDefault();
            this._browse(a.dataset.path);
          });
        }
      });
    },

    /* -- Cleanup -- */
    destroy: function (this: any) {
      if (this._onError) window.removeEventListener("error", this._onError);
      if (this._onRejection) window.removeEventListener("unhandledrejection", this._onRejection);
      if (this._onKeydown) document.removeEventListener("keydown", this._onKeydown);
    },

    /* -- Navigation (delegated to router) -- */
    go: function (this: any, path: string, push?: boolean) {
      return go(path, push);
    },

    /* -- POST action (delegated to router) -- */
    post: function (this: any, endpoint: string, data: Record<string, unknown>) {
      return post(endpoint, data);
    },

    /* -- Render response (delegated to router) -- */
    _render: (html: string) => render(html),

    /* -- Theme toggle -- */
    _themeToggle: () => {
      var html = document.documentElement;
      var next = html.getAttribute("data-theme") === "dark" ? "light" : "dark";
      html.setAttribute("data-theme", next);
      localStorage.setItem("pgv-theme", next);
      document.querySelectorAll("[data-toggle-theme]").forEach((b) => {
        b.innerHTML = next === "dark" ? "&#x2600;" : "&#x263E;";
      });
    },

    /* -- Toast -- */
    showToast: function (this: any, msg: string, level?: string, detail?: string) {
      clearTimeout(this._tt);
      this.toast = { show: true, msg: msg, level: level || "success", detail: detail || "" };

      this._tt = setTimeout(
        () => {
          this.toast.show = false;
        },
        level === "error" ? 8000 : 3000,
      );
    },

    /* -- Error handling (delegated to router) -- */
    _err: (r: Response) => handleError(r),

    /* -- Search Overlay -- */
    searchOpen: function (this: any) {
      this.search = { open: true, query: "", idx: 0 };

      this.$nextTick(() => {
        if (this.$refs.searchInput) this.$refs.searchInput.focus();
        if (this.$refs.searchResults) this.$refs.searchResults.innerHTML = "";
      });
    },

    searchClose: function (this: any) {
      this.search.open = false;
    },

    searchExec: function (this: any) {
      var q = this.search.query.trim();

      var cfg = getConfig();
      if (!q) {
        if (this.$refs.searchResults) this.$refs.searchResults.innerHTML = "";
        return;
      }
      var schema = this._currentSchema || "pgv_qa";
      fetch(cfg.rpc("/search"), {
        method: "POST",
        headers: cfg.headers("application/json", "pgv"),
        body: JSON.stringify({ p_query: q, p_schema: schema }),
      })
        .then((r) => r.json())
        .then((html: string) => {
          if (!this.search.open) return;
          this.$refs.searchResults.innerHTML = html;
          this.search.idx = 0;
          this._searchHighlight();
        })
        .catch(() => {
          if (this.$refs.searchResults)
            this.$refs.searchResults.innerHTML = `<div class="pgv-empty"><h4>${t("search.error")}</h4></div>`;
        });
    },

    searchNav: function (this: any, dir: number) {
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll(".pgv-search-item") : [];
      if (!items.length) return;
      this.search.idx = Math.max(0, Math.min(items.length - 1, this.search.idx + dir));
      this._searchHighlight();
    },

    searchSelect: function (this: any) {
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll(".pgv-search-item") : [];
      if (!items.length) return;
      var item = items[this.search.idx];
      if (!item) return;
      var href = item.dataset.href;
      if (!href) return;
      this.searchClose();
      // Prefix with schema if needed
      if (this._currentSchema && href.charAt(0) === "/" && !href.match(/^\/[a-z][a-z0-9_]*\//))
        href = `/${this._currentSchema}${href}`;
      this.go(href);
    },

    _searchHighlight: function (this: any) {
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll(".pgv-search-item") : [];
      items.forEach((el: Element, i: number) => {
        el.classList.toggle("active", i === this.search.idx);
      });
    },

    /* -- Dialog -- */
    openDialog: function (this: any, name: string, src: string, target: string) {
      this.dlg = { title: name === "folder-picker" ? t("dialog.folder") : name, target: target || "" };
      this.$refs.dlgBody.innerHTML = `<p aria-busy="true">${t("dialog.loading")}</p>`;
      this.$refs.dialog.showModal();
      this._browse(src);
    },

    _browse: function (this: any, pathOrUrl: string) {
      var url =
        pathOrUrl.indexOf("/") === 0 && pathOrUrl.indexOf("/api") !== 0
          ? `/api/browse?path=${encodeURIComponent(pathOrUrl)}`
          : pathOrUrl;

      fetch(url)
        .then((r) => r.text())
        .then((html) => {
          this.$refs.dlgBody.innerHTML = html;
        })
        .catch(() => {
          this.$refs.dlgBody.innerHTML = `<p>${t("dialog.load_error")}</p>`;
        });
    },

    dlgSelect: function (this: any) {
      var pathEl = this.$refs.dlgBody.querySelector(".folder-path");
      if (pathEl && this.dlg.target) {
        const input = document.getElementById(this.dlg.target) as HTMLInputElement | null;
        if (input) input.value = pathEl.textContent!.trim();
      }
      this.$refs.dialog.close();
    },

    /* -- Confirm Dialog -- */
    _confirm: function (this: any, msg: string): Promise<boolean> {
      var dlg = this.$refs.confirmDialog as HTMLDialogElement;
      this.$refs.confirmMsg.textContent = msg;
      dlg.showModal();
      return new Promise((resolve) => {
        const cleanup = () => {
          this.$refs.confirmYes.removeEventListener("click", onYes);
          this.$refs.confirmNo.removeEventListener("click", onNo);
          dlg.removeEventListener("cancel", onNo);
        };
        const onYes = () => {
          cleanup();
          dlg.close();
          resolve(true);
        };
        const onNo = () => {
          cleanup();
          dlg.close();
          resolve(false);
        };
        this.$refs.confirmYes.addEventListener("click", onYes);
        this.$refs.confirmNo.addEventListener("click", onNo);
        dlg.addEventListener("cancel", onNo);
      });
    },

    /* -- Form Dialog (delegated to router) -- */
    openFormDialog: function (this: any, id: string, src: string) {
      return openFormDialog(id, src);
    },

    submitFormDialog: function (this: any, form: HTMLFormElement, data: Record<string, unknown>) {
      return submitFormDialog(form, data);
    },

    /* -- Issue Report -- */
    issueFromError: function (this: any) {
      var desc = this.toast.msg || "";
      if (this.toast.detail) desc += `\n${this.toast.detail}`;
      this.toast.show = false;
      this.issue = { open: true, desc: desc, type: "bug" };
    },

    issueOpen: function (this: any) {
      this.issue = { open: true, desc: "", type: "bug" };
    },

    issueClose: function (this: any) {
      this.issue.open = false;
    },

    issueContext: function (this: any) {
      return {
        path: location.pathname + location.search,
        schema: this._currentSchema,
        errors: this._errors.slice(-5),
        actions: this._actions.slice(-10),
        viewport: `${innerWidth}x${innerHeight}`,
        userAgent: navigator.userAgent,
        timestamp: new Date().toISOString(),
      };
    },

    issueSubmit: function (this: any) {
      var desc = this.issue.desc.trim();
      if (!desc) return;

      var cfg = getConfig();
      var data = this.issueContext();
      data.description = desc;
      data.issue_type = this.issue.type;
      this.issue.open = false;
      fetch(cfg.rpc("/post_issue_report"), {
        method: "POST",
        headers: cfg.headers("application/json", "pgv"),
        body: JSON.stringify({ p: data }),
      })
        .then((r) => {
          if (!r.ok) throw new Error(String(r.status));
          this.showToast(t("issue.success"), "success");
        })
        .catch(() => {
          this.showToast(t("issue.error"), "error");
        });
    },
  };
}
