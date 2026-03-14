/**
 * shell.ts — Alpine component factory for the pgView shell
 *
 * Creates the 'pgview' Alpine data component. Thin coordinator that
 * delegates to router.ts, enhance.ts, and plugin modules.
 */

import { getConfig } from "./config.js";
import { t, loadI18n } from "./i18n.js";
import { pgListen, pgRpc } from "./realtime.js";
import { setEnhanceContext } from "./enhance.js";
import {
  initRouter,
  go,
  post,
  render,
  handleError,
  openFormDialog,
  submitFormDialog,
  type RouterState,
} from "./router.js";

/** Create and return the pgview Alpine data object */
export function createShellComponent(): Record<string, unknown> {
  return {
    toast: { show: false, msg: '', level: 'success', detail: '' },
    dlg:   { title: '', target: '' },
    search: { open: false, query: '', idx: 0 },
    issue: { open: false, desc: '', type: 'bug' },
    _tt: null as any,
    _modules: [] as any[],
    _currentSchema: null as string | null,
    _fixedSchema: null as string | null,
    _errors: [] as any[],
    _actions: [] as any[],

    /* -- Delegated to pgv kernel -- */
    t: function(key: string): string { return t(key); },
    pgListen: function(schema: string, table: string, handler: any) { return pgListen(schema, table, handler); },
    pgRpc: function(fn: string, params?: Record<string, unknown>, schema?: string) { return pgRpc(fn, params, schema); },

    /* -- Bootstrap -- */
    boot: function(this: any) {
      var self = this;

      // Proxy pattern: router reads/writes to _state,
      // but Alpine reactivity requires mutations on `self`.
      // Getters/setters keep them in sync.
      var stateProxy: RouterState = {
        get modules() { return self._modules; },
        set modules(v) { self._modules = v; },
        get currentSchema() { return self._currentSchema; },
        set currentSchema(v) { self._currentSchema = v; },
        get fixedSchema() { return self._fixedSchema; },
        set fixedSchema(v) { self._fixedSchema = v; },
        get errors() { return self._errors; },
        set errors(v) { self._errors = v; },
        get actions() { return self._actions; },
        set actions(v) { self._actions = v; },
      };

      initRouter(stateProxy, {
        showToast: function(msg, level, detail) { self.showToast(msg, level, detail); },
        nextTick: function(fn) { self.$nextTick(fn); },
      });

      setEnhanceContext({
        go: function(path) { self.go(path); },
        showToast: function(msg, level, detail) { self.showToast(msg, level, detail); },
        currentSchema: function() { return self._currentSchema; },
        nextTick: function(fn) { self.$nextTick(fn); },
      });

      // Error tracking (circular buffer, max 20) — store refs for cleanup
      self._onError = function(e: ErrorEvent) {
        self._errors.push({ msg: e.message, src: e.filename, line: e.lineno, ts: Date.now() });
        if (self._errors.length > 20) self._errors.shift();
      };
      self._onRejection = function(e: PromiseRejectionEvent) {
        self._errors.push({ msg: String(e.reason), ts: Date.now() });
        if (self._errors.length > 20) self._errors.shift();
      };
      window.addEventListener('error', self._onError);
      window.addEventListener('unhandledrejection', self._onRejection);

      var saved = localStorage.getItem('pgv-theme');
      if (saved) document.documentElement.setAttribute('data-theme', saved);
      // App mode: <meta name="pgv-schema"> fixes the schema
      // Dev mode: no meta -> extract schema from URL /{schema}/path
      var meta = document.querySelector('meta[name="pgv-schema"]');
      this._fixedSchema = meta ? meta.getAttribute('content') : null;
      this._listen();

      // Load i18n before first navigation so t() returns translated strings
      var lang = document.documentElement.lang || 'fr';
      var cfg = getConfig();
      loadI18n(lang).then(function() {
        // Multi-module: fetch app_nav before initial navigation
        if (!self._fixedSchema) {
          fetch(cfg.rpc('/app_nav'), {
            method: 'POST',
            headers: cfg.headers('application/json', 'pgv'),
            body: '{}'
          })
          .then(function(r) { return r.ok ? r.json() : []; })
          .then(function(mods: any[]) {
            self._modules = Array.isArray(mods) ? mods : [];
            if (self._modules.length > 0)
              document.documentElement.style.setProperty('--pgv-app-bar-h', '2.5rem');
            self.go((location.pathname + location.search) || '/');
          })
          .catch(function() {
            self._modules = [];
            self.go((location.pathname + location.search) || '/');
          });
        } else {
          self.go((location.pathname + location.search) || '/');
        }
      });
      window.onpopstate = function() { self.go(location.pathname + location.search || '/', false); };
    },

    /* -- Event delegation on #app -- */
    _listen: function(this: any) {
      var self = this;
      var app = document.getElementById('app')!;

      // Cmd+K / Ctrl+K -> toggle search overlay — store ref for cleanup
      self._onKeydown = function(e: KeyboardEvent) {
        if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
          e.preventDefault();
          if (self.search.open) self.searchClose();
          else self.searchOpen();
        }
      };
      document.addEventListener('keydown', self._onKeydown);

      app.addEventListener('click', function(e: Event) {
        // Internal links
        var a = (e.target as Element).closest('a[href^="/"]');
        if (a) { e.preventDefault(); return self.go(a.getAttribute('href')); }

        // data-rpc buttons
        var btn = (e.target as Element).closest('button[data-rpc]') as HTMLElement | null;
        if (btn) {
          e.preventDefault();
          var params = btn.dataset.params ? JSON.parse(btn.dataset.params) : {};
          if (btn.dataset.confirm) {
            self._confirm(btn.dataset.confirm).then(function(ok: boolean) {
              if (ok) self.post(btn!.dataset.rpc, params);
            });
            return;
          }
          return self.post(btn.dataset.rpc, params);
        }

        // Theme toggle
        var thm = (e.target as Element).closest('[data-toggle-theme]');
        if (thm) {
          e.preventDefault();
          return self._themeToggle();
        }

        // data-dialog buttons
        var dlg = (e.target as Element).closest('[data-dialog]') as HTMLElement | null;
        if (dlg) {
          e.preventDefault();
          return self.openDialog(dlg.dataset.dialog, dlg.dataset.src, dlg.dataset.target);
        }

        // data-form-dialog buttons (open modal form)
        var fd = (e.target as Element).closest('[data-form-dialog]') as HTMLElement | null;
        if (fd) {
          e.preventDefault();
          return self.openFormDialog(fd.dataset.formDialog, fd.dataset.src);
        }
      });

      app.addEventListener('submit', function(e: Event) {
        var form = (e.target as Element).closest('form[data-rpc]') as HTMLFormElement | null;
        if (form) {
          e.preventDefault();
          var data: Record<string, unknown> = {};
          new FormData(form).forEach(function(v, k) { data[k] = v; });
          if (form.hasAttribute('data-dialog-form')) {
            self.submitFormDialog(form, data);
          } else {
            self.post(form.dataset.rpc, data);
          }
          return;
        }
        // Filter forms: GET with query params -> SPA navigation
        var filter = (e.target as Element).closest('form[data-filter]') as HTMLFormElement | null;
        if (filter) {
          e.preventDefault();
          var parts: string[] = [];
          new FormData(filter).forEach(function(v, k) {
            if (v !== '') parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(v as string));
          });
          var qs = parts.join('&');
          self.go(location.pathname + (qs ? '?' + qs : ''));
        }
      });

      // Dialog folder navigation — defer to $nextTick in case dlgBody is conditional
      this.$nextTick(function() {
        if (self.$refs.dlgBody) {
          self.$refs.dlgBody.addEventListener('click', function(e: Event) {
            var a = (e.target as Element).closest('a[data-path]') as HTMLElement | null;
            if (!a) return;
            e.preventDefault();
            self._browse(a.dataset.path);
          });
        }
      });
    },

    /* -- Cleanup -- */
    destroy: function(this: any) {
      if (this._onError) window.removeEventListener('error', this._onError);
      if (this._onRejection) window.removeEventListener('unhandledrejection', this._onRejection);
      if (this._onKeydown) document.removeEventListener('keydown', this._onKeydown);
    },

    /* -- Navigation (delegated to router) -- */
    go: function(this: any, path: string, push?: boolean) {
      return go(path, push);
    },

    /* -- POST action (delegated to router) -- */
    post: function(this: any, endpoint: string, data: Record<string, unknown>) {
      return post(endpoint, data);
    },

    /* -- Render response (delegated to router) -- */
    _render: function(html: string) {
      return render(html);
    },

    /* -- Theme toggle -- */
    _themeToggle: function() {
      var html = document.documentElement;
      var next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      html.setAttribute('data-theme', next);
      localStorage.setItem('pgv-theme', next);
      document.querySelectorAll('[data-toggle-theme]').forEach(function(b) {
        b.innerHTML = next === 'dark' ? '&#x2600;' : '&#x263E;';
      });
    },

    /* -- Toast -- */
    showToast: function(this: any, msg: string, level?: string, detail?: string) {
      clearTimeout(this._tt);
      this.toast = { show: true, msg: msg, level: level || 'success', detail: detail || '' };
      var self = this;
      this._tt = setTimeout(function() { self.toast.show = false; },
        level === 'error' ? 8000 : 3000);
    },

    /* -- Error handling (delegated to router) -- */
    _err: function(r: Response) {
      return handleError(r);
    },

    /* -- Search Overlay -- */
    searchOpen: function(this: any) {
      this.search = { open: true, query: '', idx: 0 };
      var self = this;
      this.$nextTick(function() {
        if (self.$refs.searchInput) self.$refs.searchInput.focus();
        if (self.$refs.searchResults) self.$refs.searchResults.innerHTML = '';
      });
    },

    searchClose: function(this: any) {
      this.search.open = false;
    },

    searchExec: function(this: any) {
      var q = this.search.query.trim();
      var self = this;
      var cfg = getConfig();
      if (!q) {
        if (self.$refs.searchResults) self.$refs.searchResults.innerHTML = '';
        return;
      }
      var schema = this._currentSchema || 'pgv_qa';
      fetch(cfg.rpc('/search'), {
        method: 'POST',
        headers: cfg.headers('application/json', 'pgv'),
        body: JSON.stringify({ p_query: q, p_schema: schema })
      })
      .then(function(r) { return r.json(); })
      .then(function(html: string) {
        if (!self.search.open) return;
        self.$refs.searchResults.innerHTML = html;
        self.search.idx = 0;
        self._searchHighlight();
      })
      .catch(function() {
        if (self.$refs.searchResults) self.$refs.searchResults.innerHTML = '<div class="pgv-empty"><h4>' + t('search.error') + '</h4></div>';
      });
    },

    searchNav: function(this: any, dir: number) {
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll('.pgv-search-item') : [];
      if (!items.length) return;
      this.search.idx = Math.max(0, Math.min(items.length - 1, this.search.idx + dir));
      this._searchHighlight();
    },

    searchSelect: function(this: any) {
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll('.pgv-search-item') : [];
      if (!items.length) return;
      var item = items[this.search.idx];
      if (!item) return;
      var href = item.dataset.href;
      if (!href) return;
      this.searchClose();
      // Prefix with schema if needed
      if (this._currentSchema && href.charAt(0) === '/' && !href.match(/^\/[a-z][a-z0-9_]*\//))
        href = '/' + this._currentSchema + href;
      this.go(href);
    },

    _searchHighlight: function(this: any) {
      var self = this;
      var items = this.$refs.searchResults ? this.$refs.searchResults.querySelectorAll('.pgv-search-item') : [];
      items.forEach(function(el: Element, i: number) {
        el.classList.toggle('active', i === self.search.idx);
      });
    },

    /* -- Dialog -- */
    openDialog: function(this: any, name: string, src: string, target: string) {
      this.dlg = { title: name === 'folder-picker' ? t('dialog.folder') : name, target: target || '' };
      this.$refs.dlgBody.innerHTML = '<p aria-busy="true">' + t('dialog.loading') + '</p>';
      this.$refs.dialog.showModal();
      this._browse(src);
    },

    _browse: function(this: any, pathOrUrl: string) {
      var url = pathOrUrl.indexOf('/') === 0 && pathOrUrl.indexOf('/api') !== 0
        ? '/api/browse?path=' + encodeURIComponent(pathOrUrl)
        : pathOrUrl;
      var self = this;
      fetch(url).then(function(r) { return r.text(); })
        .then(function(html) { self.$refs.dlgBody.innerHTML = html; })
        .catch(function() { self.$refs.dlgBody.innerHTML = '<p>' + t('dialog.load_error') + '</p>'; });
    },

    dlgSelect: function(this: any) {
      var pathEl = this.$refs.dlgBody.querySelector('.folder-path');
      if (pathEl && this.dlg.target) {
        var input = document.getElementById(this.dlg.target) as HTMLInputElement | null;
        if (input) input.value = pathEl.textContent!.trim();
      }
      this.$refs.dialog.close();
    },

    /* -- Confirm Dialog -- */
    _confirm: function(this: any, msg: string): Promise<boolean> {
      var dlg = this.$refs.confirmDialog as HTMLDialogElement;
      this.$refs.confirmMsg.textContent = msg;
      dlg.showModal();
      var self = this;
      return new Promise(function(resolve) {
        function cleanup() {
          self.$refs.confirmYes.removeEventListener('click', onYes);
          self.$refs.confirmNo.removeEventListener('click', onNo);
          dlg.removeEventListener('cancel', onNo);
        }
        function onYes() { cleanup(); dlg.close(); resolve(true); }
        function onNo()  { cleanup(); dlg.close(); resolve(false); }
        self.$refs.confirmYes.addEventListener('click', onYes);
        self.$refs.confirmNo.addEventListener('click', onNo);
        dlg.addEventListener('cancel', onNo);
      });
    },

    /* -- Form Dialog (delegated to router) -- */
    openFormDialog: function(this: any, id: string, src: string) {
      return openFormDialog(id, src);
    },

    submitFormDialog: function(this: any, form: HTMLFormElement, data: Record<string, unknown>) {
      return submitFormDialog(form, data);
    },

    /* -- Issue Report -- */
    issueFromError: function(this: any) {
      var desc = this.toast.msg || '';
      if (this.toast.detail) desc += '\n' + this.toast.detail;
      this.toast.show = false;
      this.issue = { open: true, desc: desc, type: 'bug' };
    },

    issueOpen: function(this: any) {
      this.issue = { open: true, desc: '', type: 'bug' };
    },

    issueClose: function(this: any) {
      this.issue.open = false;
    },

    issueContext: function(this: any) {
      return {
        path: location.pathname + location.search,
        schema: this._currentSchema,
        errors: this._errors.slice(-5),
        actions: this._actions.slice(-10),
        viewport: innerWidth + 'x' + innerHeight,
        userAgent: navigator.userAgent,
        timestamp: new Date().toISOString()
      };
    },

    issueSubmit: function(this: any) {
      var desc = this.issue.desc.trim();
      if (!desc) return;
      var self = this;
      var cfg = getConfig();
      var data = this.issueContext();
      data.description = desc;
      data.issue_type = this.issue.type;
      this.issue.open = false;
      fetch(cfg.rpc('/post_issue_report'), {
        method: 'POST',
        headers: cfg.headers('application/json', 'pgv'),
        body: JSON.stringify({ p: data })
      })
      .then(function(r) {
        if (!r.ok) throw new Error(String(r.status));
        self.showToast(t('issue.success'), 'success');
      })
      .catch(function() {
        self.showToast(t('issue.error'), 'error');
      });
    }
  };
}
