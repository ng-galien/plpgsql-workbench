/**
 * enhance.ts — DOM enhancement after SPA navigation
 *
 * Post-processes rendered HTML: markdown tables, clickable rows, scripts,
 * select-search widgets, filter bars, lazy-load containers, illustrator detection.
 * Also hosts pgv.mount() / pgv.unmount() plugin system.
 */

import { getConfig } from "./config.js";
import { t } from "./i18n.js";
import { loadIllustrator } from "./plugins/illustrator.js";

declare const marked: any;
declare const Alpine: any;

// ── Plugin system (pgv.mount / pgv.unmount) ──────────────────────
// Moved from the inline IIFE in index.html.
// The plugin runtime (pgv.plugin, pgv._flushPlugins, pgv.mount, pgv.unmount)
// stays in the inline <script> block because pgv-modules.js registers
// plugins before this bundle loads. We only re-export mount/unmount references
// so the enhance code can call them.

/**
 * Context provided by the shell to enhance/initTable functions.
 * Avoids coupling enhance.ts to the Alpine component directly.
 */
export interface EnhanceContext {
  go: (path: string) => void;
  showToast: (msg: string, level?: string, detail?: string) => void;
  currentSchema: () => string | null;
  nextTick: (fn: () => void) => void;
}

let _ctx: EnhanceContext | null = null;

/** Bind the shell context — called once during boot */
export function setEnhanceContext(ctx: EnhanceContext): void {
  _ctx = ctx;
}

/** Initialize sort + pagination on a markdown-generated table */
export function initTable(wrap: HTMLElement, tbl: HTMLTableElement, pageSize: number): void {
  var tbody = tbl.querySelector('tbody');
  if (!tbody) return;
  var allRows = Array.from(tbody.querySelectorAll('tr'));
  var page = 0;
  var pager: HTMLElement | null = null;

  function render() {
    var rows = allRows;
    if (pageSize > 0) {
      var start = page * pageSize;
      rows.forEach(function(r) { (r as HTMLElement).style.display = 'none'; });
      rows.slice(start, start + pageSize).forEach(function(r) { (r as HTMLElement).style.display = ''; });
      renderPager();
    }
  }

  function renderPager() {
    if (!pageSize || allRows.length <= pageSize) {
      if (pager) pager.style.display = 'none';
      return;
    }
    if (!pager) {
      pager = document.createElement('div');
      pager.className = 'pgv-pager';
      wrap.appendChild(pager);
    }
    pager.style.display = '';
    var total = allRows.length;
    var pages = Math.ceil(total / pageSize);
    var start = page * pageSize + 1;
    var end = Math.min(start + pageSize - 1, total);

    var h = '<span class="pgv-pager-info">' + start + '-' + end + ' / ' + total + '</span>';
    h += '<span class="pgv-pager-btns">';
    h += '<button ' + (page === 0 ? 'disabled' : 'data-page="' + (page - 1) + '"') + '>&lsaquo;</button>';
    for (var i = 0; i < pages; i++) {
      if (pages > 7 && i > 1 && i < pages - 2 && Math.abs(i - page) > 1) {
        if (i === 2 || i === pages - 3) h += '<span class="pgv-pager-dots">&hellip;</span>';
        continue;
      }
      h += '<button ' + (i === page ? 'class="active"' : 'data-page="' + i + '"') + '>' + (i + 1) + '</button>';
    }
    h += '<button ' + (page >= pages - 1 ? 'disabled' : 'data-page="' + (page + 1) + '"') + '>&rsaquo;</button>';
    h += '</span>';
    pager.innerHTML = h;

    pager.querySelectorAll('[data-page]').forEach(function(btn: Element) {
      btn.addEventListener('click', function() {
        page = parseInt((btn as HTMLElement).dataset.page!);
        render();
      });
    });
  }

  function compare(col: number, asc: boolean) {
    return function(a: Element, b: Element) {
      var av = ((a as HTMLTableRowElement).children[col] || {} as any).textContent || '';
      var bv = ((b as HTMLTableRowElement).children[col] || {} as any).textContent || '';
      var an = parseFloat(av.replace(/[^\d.,-]/g, '').replace(',', '.'));
      var bn = parseFloat(bv.replace(/[^\d.,-]/g, '').replace(',', '.'));
      if (!isNaN(an) && !isNaN(bn)) return asc ? an - bn : bn - an;
      var ad = av.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
      var bd = bv.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
      if (ad && bd) {
        var da = ad[3] + ad[2] + ad[1], db = bd[3] + bd[2] + bd[1];
        return asc ? da.localeCompare(db) : db.localeCompare(da);
      }
      return asc ? av.localeCompare(bv) : bv.localeCompare(av);
    };
  }

  var ths = tbl.querySelectorAll('thead th');
  ths.forEach(function(th: Element, col: number) {
    th.classList.add('pgv-sortable');
    th.addEventListener('click', function() {
      var asc = (th as HTMLElement).dataset.sort !== 'asc';
      ths.forEach(function(h: Element) { (h as HTMLElement).dataset.sort = ''; });
      (th as HTMLElement).dataset.sort = asc ? 'asc' : 'desc';
      allRows.sort(compare(col, asc));
      allRows.forEach(function(r) { tbody!.appendChild(r); });
      page = 0;
      render();
    });
  });

  render();
}

/** Enhance DOM after SPA navigation — markdown, scripts, clickable rows, widgets */
export function enhance(el: HTMLElement): void {
  var ctx = _ctx!;
  // Sync all theme toggle icons
  var icon = document.documentElement.getAttribute('data-theme') === 'dark' ? '&#x2600;' : '&#x263E;';
  document.querySelectorAll('[data-toggle-theme]').forEach(function(b) { b.innerHTML = icon; });

  // <md> -> rendered markdown, tables wrapped in .pgv-table
  el.querySelectorAll('md').forEach(function(md: Element) {
    var pageSize = parseInt((md as HTMLElement).dataset.page!) || 0;
    var div = document.createElement('div');
    div.innerHTML = marked.parse((md as HTMLElement).innerHTML.trim());
    div.querySelectorAll('table').forEach(function(tbl: HTMLTableElement) {
      var wrap = document.createElement('div');
      wrap.className = 'pgv-table';
      tbl.parentNode!.insertBefore(wrap, tbl);
      wrap.appendChild(tbl);
      initTable(wrap, tbl, pageSize);
    });
    md.parentNode!.replaceChild(div, md);
  });

  // Clickable table rows
  el.querySelectorAll('tbody tr').forEach(function(tr: Element) {
    var a = tr.querySelector('a[href^="/"]');
    if (!a) return;
    (tr as HTMLElement).style.cursor = 'pointer';
    tr.addEventListener('click', function(e: Event) {
      if ((e.target as Element).closest('a, button')) return;
      ctx.go(a!.getAttribute('href')!);
    });
  });

  // Execute <script> tags injected via innerHTML
  el.querySelectorAll('script').forEach(function(old: HTMLScriptElement) {
    var s = document.createElement('script');
    if (old.src) { s.src = old.src; }
    else { s.textContent = old.textContent; }
    old.parentNode!.replaceChild(s, old);
  });

  // Illustrator: detect data-illustrator marker, load D3 + app bundle
  var illEl = el.querySelector('[data-illustrator]') as HTMLElement | null;
  if (illEl) {
    loadIllustrator(illEl.dataset.illustrator!);
    return; // skip further enhance -- illustrator takes over
  }

  // Initialize Alpine.js on new DOM (module fragments with x-data)
  if (typeof Alpine !== 'undefined') Alpine.initTree(el);
  (window as any).pgv.mount(el);

  // Select-search: async combo input + dropdown from RPC
  _enhanceSelectSearch(el, ctx);

  // Filter bar: chips for active filters + auto-submit selects
  _enhanceFilterBar(el, ctx);

  // Lazy-load containers: fetch content when scrolled into view
  _enhanceLazyLoad(el, ctx);
}

/** Load lazy content for a container */
export function loadLazy(container: HTMLElement): void {
  var ctx = _ctx!;
  var cfg = getConfig();
  var rpc = container.dataset.lazy!;
  var params = container.dataset.params ? JSON.parse(container.dataset.params) : {};
  var schema = ctx.currentSchema();
  // Route via pgv.route() -- returns text/html domain
  var path = '/' + rpc.replace(/^get_/, '');
  fetch(cfg.rpc('/route'), {
    method: 'POST',
    headers: cfg.headers('text/html'),
    body: JSON.stringify({ p_schema: schema, p_path: path, p_method: 'GET', p_params: params })
  })
  .then(function(r) {
    if (!r.ok) throw new Error(String(r.status));
    return r.text();
  })
  .then(function(html) {
    container.innerHTML = html;
    enhance(container);
  })
  .catch(function() {
    container.innerHTML = '<p>' + t('error.load') + '</p>';
  });
}

// ── Select-search widget ──────────────────────────────────────────

function _enhanceSelectSearch(el: HTMLElement, ctx: EnhanceContext): void {
  var cfg = getConfig();
  el.querySelectorAll('[data-ss-rpc]:not([data-ss-init])').forEach(function(ss: Element) {
    (ss as HTMLElement).setAttribute('data-ss-init', '');
    var rpc = (ss as HTMLElement).dataset.ssRpc!;
    var parts = rpc.split('.');
    var schema = parts.length > 1 ? parts[0] : ctx.currentSchema();
    var fn = parts.length > 1 ? parts[1] : parts[0];
    var inp = ss.querySelector('.pgv-ss-input') as HTMLInputElement;
    var hid = ss.querySelector('input[type="hidden"]') as HTMLInputElement;
    var box = ss.querySelector('.pgv-ss-results') as HTMLElement;
    var timer: any = null;
    var idx = -1;

    function doFetch(q: string) {
      box.innerHTML = '<div class="pgv-ss-loading">...</div>';
      ss.classList.add('open');
      var body: Record<string, unknown> = {};
      if (q) body.p_search = q;
      fetch(cfg.rpc('/') + fn, {
        method: 'POST',
        headers: cfg.headers('application/json', schema!),
        body: JSON.stringify(body)
      })
      .then(function(r) { return r.json(); })
      .then(function(rows: any[]) {
        if (!rows || !rows.length) { box.innerHTML = '<div class="pgv-ss-empty">' + t('search.no_results') + '</div>'; return; }
        idx = -1;
        box.innerHTML = '';
        rows.forEach(function(r: any) {
          var d = document.createElement('div');
          d.className = 'pgv-ss-item';
          d.dataset.value = r.value;
          d.textContent = r.label || r.value;
          if (r.detail) { var s = document.createElement('small'); s.textContent = r.detail; d.appendChild(s); }
          d.addEventListener('mousedown', function(e) {
            e.preventDefault();
            pick(r.value, r.label || r.value);
          });
          box.appendChild(d);
        });
      })
      .catch(function() { box.innerHTML = '<div class="pgv-ss-empty">' + t('search.error') + '</div>'; });
    }

    function pick(val: string, label: string) {
      hid.value = val;
      inp.value = label;
      ss.classList.remove('open');
      hid.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function nav(dir: number) {
      var items = box.querySelectorAll('.pgv-ss-item');
      if (!items.length) return;
      if (idx >= 0 && idx < items.length) items[idx].classList.remove('active');
      idx = Math.max(0, Math.min(items.length - 1, idx + dir));
      items[idx].classList.add('active');
      items[idx].scrollIntoView({ block: 'nearest' });
    }

    inp.addEventListener('focus', function() { if (!box.children.length) doFetch(inp.value); else ss.classList.add('open'); });
    inp.addEventListener('input', function() {
      hid.value = '';
      clearTimeout(timer);
      timer = setTimeout(function() { doFetch(inp.value); }, 200);
    });
    inp.addEventListener('blur', function() { setTimeout(function() { ss.classList.remove('open'); }, 150); });
    inp.addEventListener('keydown', function(e: KeyboardEvent) {
      if (e.key === 'ArrowDown') { e.preventDefault(); nav(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); nav(-1); }
      else if (e.key === 'Enter') {
        e.preventDefault();
        var items = box.querySelectorAll('.pgv-ss-item');
        if (idx >= 0 && idx < items.length) pick((items[idx] as HTMLElement).dataset.value!, items[idx].textContent!.split('\n')[0]);
      }
      else if (e.key === 'Escape') { ss.classList.remove('open'); inp.blur(); }
    });
  });
}

// ── Filter bar ────────────────────────────────────────────────────

function _enhanceFilterBar(el: HTMLElement, ctx: EnhanceContext): void {
  el.querySelectorAll('.pgv-filter').forEach(function(wrap: Element) {
    var form = wrap.querySelector('form[data-filter]') as HTMLFormElement | null;
    var chipsEl = wrap.querySelector('.pgv-filter-chips') as HTMLElement | null;
    if (!form || !chipsEl) return;
    var chips = chipsEl;
    var params = new URLSearchParams(location.search);
    var hasActive = false;
    chips.innerHTML = '';
    form.querySelectorAll('input, select').forEach(function(input: Element) {
      var inp = input as HTMLInputElement | HTMLSelectElement;
      if ((inp as HTMLInputElement).type === 'submit' || (inp as HTMLInputElement).type === 'button' || (inp as HTMLInputElement).type === 'hidden') return;
      var val = params.get(inp.name);
      if (!val) return;
      // Pre-fill input from URL
      inp.value = val;
      hasActive = true;
      var label = (inp as HTMLInputElement).placeholder || inp.dataset.label || inp.name;
      var displayVal = val;
      if (inp.tagName === 'SELECT') {
        var opt = inp.querySelector('option[value="' + CSS.escape(val) + '"]');
        if (opt) displayVal = opt.textContent!;
      }
      var chip = document.createElement('span');
      chip.className = 'pgv-filter-chip';
      chip.innerHTML = '<span>' + label + ': <strong>' + displayVal + '</strong></span>'
        + '<button type="button" data-filter-clear="' + inp.name + '">&times;</button>';
      chips.appendChild(chip);
    });
    if (hasActive) {
      var clear = document.createElement('a');
      clear.href = '#';
      clear.className = 'pgv-filter-clear';
      clear.textContent = t('filter.clear');
      clear.addEventListener('click', function(e) {
        e.preventDefault();
        ctx.go(location.pathname);
      });
      chips.appendChild(clear);
    }
    // Chip x click: clear individual filter
    chips.addEventListener('click', function(e: Event) {
      var btn = (e.target as Element).closest('[data-filter-clear]') as HTMLElement | null;
      if (!btn) return;
      var name = btn.dataset.filterClear!;
      var p = new URLSearchParams(location.search);
      p.delete(name);
      var qs = p.toString();
      ctx.go(location.pathname + (qs ? '?' + qs : ''));
    });
    // Auto-submit on select change
    form.querySelectorAll('select').forEach(function(sel: Element) {
      sel.addEventListener('change', function() {
        form!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
      });
    });
  });
}

// ── Lazy-load ─────────────────────────────────────────────────────

function _enhanceLazyLoad(el: HTMLElement, _ctx: EnhanceContext): void {
  el.querySelectorAll('[data-lazy]:not([data-loaded])').forEach(function(lazy: Element) {
    var obs = new IntersectionObserver(function(entries) {
      if (entries[0].isIntersecting) {
        obs.disconnect();
        (lazy as HTMLElement).setAttribute('data-loaded', '');
        loadLazy(lazy as HTMLElement);
      }
    }, { rootMargin: '200px' });
    obs.observe(lazy);
  });
}
