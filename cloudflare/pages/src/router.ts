/**
 * router.ts — SPA navigation (go, post, render, error handling, home)
 *
 * Manages page navigation, POST actions, response rendering,
 * and the home page (module cards).
 */

import { getConfig } from "./config.js";
import { t } from "./i18n.js";
import { enhance } from "./enhance.js";
import type { AppModule } from "./types.js";

/** Router state — shared between all navigation functions */
export interface RouterState {
  modules: AppModule[];
  currentSchema: string | null;
  fixedSchema: string | null;
  errors: { msg: string; src?: string; line?: number; ts: number }[];
  actions: { type: string; [key: string]: unknown }[];
}

/** Callbacks the router needs from the shell Alpine component */
export interface RouterCallbacks {
  showToast: (msg: string, level?: string, detail?: string) => void;
  nextTick: (fn: () => void) => void;
}

let _state: RouterState;
let _cb: RouterCallbacks;

/** Initialize the router with shared state and shell callbacks (singleton) */
export function initRouter(state: RouterState, callbacks: RouterCallbacks): void {
  if (_state) console.warn('[pgv] initRouter called more than once');
  _state = state;
  _cb = callbacks;
}

/** SPA navigation — fetch page from PostgREST and render */
export function go(path: string, push?: boolean): Promise<void> | void {
  if (push === undefined) push = true;
  var cfg = getConfig();
  _state.actions.push({ type: 'go', path: path, ts: Date.now() });
  if (_state.actions.length > 30) _state.actions.shift();

  // Home page: render module cards
  if (!_state.fixedSchema && _state.modules.length > 0 && (path === '/' || path === '')) {
    _state.currentSchema = null;
    renderHome();
    if (push) history.pushState({}, '', '/');
    window.scrollTo(0, 0);
    return;
  }

  // Resolve schema + route path
  var rpcUrl: string, body: Record<string, unknown>;
  if (_state.fixedSchema) {
    // App mode: single schema, use page(p_path)
    rpcUrl = cfg.rpc('/page');
    body = { p_path: path };
    _state.currentSchema = _state.fixedSchema;
  } else {
    // Route mode: /{schema}/path?params -> pgv.route(schema, path, method, params)
    var m = path.match(/^\/([a-z][a-z0-9_]*)(\/[^?]*)?\??(.*)$/);
    if (m) {
      rpcUrl = cfg.rpc('/route');
      var params: Record<string, string> = {};
      if (m[3]) new URLSearchParams(m[3]).forEach(function(v, k) { params[k] = v; });
      body = { p_schema: m[1], p_path: m[2] || '/', p_method: 'GET', p_params: params };
      _state.currentSchema = m[1];
    } else {
      // Root path or no schema prefix -> show home (module cards)
      renderHome();
      if (push) history.pushState({}, '', '/');
      window.scrollTo(0, 0);
      return;
    }
  }

  return fetch(rpcUrl, {
    method: 'POST',
    headers: cfg.headers('text/html'),
    body: JSON.stringify(body)
  })
  .then(function(r) {
    if (!r.ok) return handleError(r);
    return r.text().then(function(html) {
      render(html);
      if (push) history.pushState({}, '', path);
      window.scrollTo(0, 0);
    });
  })
  .catch(function() {
    _cb.showToast(t('error.network'), 'error', t('error.unreachable'));
  });
}

/** POST action — submit data to PostgREST via pgv.route() */
export function post(endpoint: string, data: Record<string, unknown>): Promise<void> | void {
  var cfg = getConfig();
  _state.actions.push({ type: 'post', endpoint: endpoint, ts: Date.now() });
  if (_state.actions.length > 30) _state.actions.shift();
  var schema: string | null, fn: string;
  if (endpoint.indexOf('.') !== -1) {
    var parts = endpoint.split('.');
    schema = parts[0];
    fn = parts[1];
  } else {
    schema = _state.currentSchema;
    fn = endpoint;
  }
  // Route via pgv.route() -- returns text/html domain
  var path = '/' + fn.replace(/^post_/, '');
  return fetch(cfg.rpc('/route'), {
    method: 'POST',
    headers: cfg.headers('text/html'),
    body: JSON.stringify({ p_schema: schema, p_path: path, p_method: 'POST', p_params: data })
  })
  .then(function(r) {
    if (!r.ok) return handleError(r);
    return r.text().then(function(html) { render(html); });
  })
  .catch(function() {
    _cb.showToast(t('error.network'), 'error', t('error.unreachable'));
  });
}

/** Render response HTML — extract toasts, redirects, then inject into #app */
export function render(html: string): void {
  // Extract <template data-toast="level">message</template>
  var tm = html.match(/<template data-toast="([^"]*)">([\s\S]*?)<\/template>/);
  if (tm) {
    _cb.showToast(tm[2].trim(), tm[1]);
    html = html.replace(tm[0], '');
  }

  // Extract <template data-redirect="/path"></template>
  var rm = html.match(/<template data-redirect="([^"]+)"><\/template>/);
  if (rm) {
    var rpath = rm[1];
    // Prefix with schema if path is relative (no schema segment)
    if (_state.currentSchema && !rpath.match(/^\/[a-z][a-z0-9_]*\//))
      rpath = '/' + _state.currentSchema + rpath;
    go(rpath); return;
  }

  // Render page content
  if (!html.trim()) return;
  var app = document.getElementById('app')!;
  (window as any).pgv.unmount();
  app.innerHTML = html;

  // Post-process: markdown, scripts, clickable rows
  _cb.nextTick(function() { enhance(app); });
}

/** Handle HTTP error responses */
export function handleError(r: Response): Promise<void> {
  var status = r.status;
  return r.json().then(function(e: any) {
    if (e.message) {
      var title = status + ' — ' + (e.code || t('error.prefix'));
      var detail = e.message + (e.hint ? ' (' + e.hint + ')' : '');
      _cb.showToast(title, 'error', detail);
    } else {
      _cb.showToast(t('error.prefix') + ' ' + status, 'error');
    }
  }).catch(function() {
    _cb.showToast(t('error.prefix') + ' ' + status, 'error');
  });
}

/** Render the home page with module cards */
export function renderHome(): void {
  var h = '<main class="container"><hgroup><h2>' + t('apps') + '</h2></hgroup>';
  h += '<div class="pgv-app-grid">';
  for (var i = 0; i < _state.modules.length; i++) {
    var m = _state.modules[i];
    h += '<article class="pgv-app-card">';
    h += '<header>' + m.brand + '</header>';
    h += '<ul>';
    for (var j = 0; j < m.items.length; j++) {
      var it = m.items[j];
      h += '<li><a href="/' + m.schema + (it.href || '/') + '">';
      if (it.icon) h += '<span class="pgv-app-card-icon">' + it.icon + '</span> ';
      h += (it.label || '') + '</a></li>';
    }
    h += '</ul>';
    h += '<footer><a href="/' + m.schema + '/">' + t('open_module') + ' &rarr;</a></footer>';
    h += '</article>';
  }
  h += '</div></main>';
  var app = document.getElementById('app')!;
  (window as any).pgv.unmount();
  app.innerHTML = h;
  _cb.nextTick(function() { enhance(app); });
}

/** Open a form dialog, optionally fetching content from a route */
export function openFormDialog(id: string, src: string | undefined): void {
  var cfg = getConfig();
  var dlg = document.getElementById(id) as HTMLDialogElement | null;
  if (!dlg) return;
  if (src) {
    var body = dlg.querySelector('.pgv-form-dialog-body') as HTMLElement;
    body.innerHTML = '<p aria-busy="true">' + t('loading') + '</p>';
    dlg.showModal();
    var schema = _state.currentSchema;
    var raw = src.charAt(0) === '/' ? src : '/' + src;
    var parts = raw.split('?');
    var path = parts[0];
    var params: Record<string, string> = {};
    if (parts[1]) new URLSearchParams(parts[1]).forEach(function(v, k) { params[k] = v; });
    fetch(cfg.rpc('/route'), {
      method: 'POST',
      headers: cfg.headers('text/html'),
      body: JSON.stringify({ p_schema: schema, p_path: path, p_method: 'GET', p_params: params })
    })
    .then(function(r) { return r.ok ? r.text() : Promise.reject(r); })
    .then(function(html) {
      body.innerHTML = html;
      enhance(body);
    })
    .catch(function() { body.innerHTML = '<p>' + t('error.load') + '</p>'; });
  } else {
    dlg.showModal();
  }
}

/** Submit a form dialog via POST, then reload current page */
export function submitFormDialog(form: HTMLFormElement, data: Record<string, unknown>): void {
  var cfg = getConfig();
  var dlg = form.closest('dialog') as HTMLDialogElement | null;
  var rpc = form.dataset.rpc!;
  var schema = _state.currentSchema;
  var path = '/' + rpc.replace(/^post_/, '');
  fetch(cfg.rpc('/route'), {
    method: 'POST',
    headers: cfg.headers('text/html'),
    body: JSON.stringify({ p_schema: schema, p_path: path, p_method: 'POST', p_params: data })
  })
  .then(function(r) {
    if (!r.ok) return handleError(r);
    return r.text().then(function(html) {
      var tm = html.match(/<template data-toast="([^"]*)">([\s\S]*?)<\/template>/);
      if (tm) _cb.showToast(tm[2].trim(), tm[1]);
      if (dlg) dlg.close();
      // Reload current page
      go(location.pathname + location.search, false);
    });
  })
  .catch(function() {
    _cb.showToast(t('error.network'), 'error');
  });
}
