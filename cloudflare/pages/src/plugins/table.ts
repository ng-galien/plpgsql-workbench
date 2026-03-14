/**
 * plugins/table.ts — pgvTable Alpine component
 *
 * Declarative table with server-side filters, pagination, and client-side sorting.
 * Registered as Alpine.data('pgvTable', ...).
 */

import { getConfig } from "../config.js";
import { t } from "../i18n.js";

/** HTML-escape a value for safe injection */
function _esc(s: unknown): string {
  if (s == null) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

interface TableColumn {
  key: string;
  label: string;
  class?: string;
  href?: string;
}

interface TableFilter {
  name: string;
  label: string;
  type?: string;
  options?: [string, string][];
}

interface TableConfig {
  rpc: string;
  schema: string;
  cols: TableColumn[];
  filters?: TableFilter[];
  page_size?: number;
}

/** Navigate callback — the shell provides its go() function */
export type GoFn = (path: string) => void;

let _goFn: GoFn | null = null;

/** Set the navigation function used by pgvTable row clicks */
export function setTableGoFn(fn: GoFn): void {
  _goFn = fn;
}

/** Register the pgvTable Alpine component */
export function registerTable(Alpine: any): void {
  Alpine.data('pgvTable', function(this: any) { return {
    _cfg: null as TableConfig | null,
    _rows: [] as unknown[][],
    _offset: 0,
    _size: 20,
    _hasMore: false,
    _sort: null as number | null,
    _sortDir: 'asc' as 'asc' | 'desc',
    _filters: {} as Record<string, string>,
    _loading: true,
    _rootEl: null as HTMLElement | null,

    _t: function(key: string): string { return t(key); },

    init: function(this: any) {
      this._rootEl = this.$el;
      this._cfg = JSON.parse(this._rootEl.dataset.config);
      this._size = this._cfg!.page_size || 20;
      var self = this;
      (this._cfg!.filters || []).forEach(function(f: TableFilter) { self._filters[f.name] = ''; });
      // Stable filter bar + dynamic data zone
      this._rootEl!.innerHTML = this._filtersHtml()
        + '<div data-pgv-chips></div>'
        + '<div data-pgv-data></div>';
      this._bindFilters();
      this._doFetch();
    },

    _doFetch: function(this: any) {
      var self = this;
      var cfg = getConfig();
      this._loading = true;
      this._paintData();
      var p: Record<string, unknown> = {};
      Object.keys(this._filters).forEach(function(k: string) {
        if (self._filters[k]) p[k] = self._filters[k];
      });
      p._offset = this._offset;
      p._size = this._size;
      fetch(cfg.rpc('/') + this._cfg!.rpc, {
        method: 'POST',
        headers: cfg.headers('application/json', this._cfg!.schema),
        body: JSON.stringify({ p_params: p })
      })
      .then(function(r: Response) { return r.json(); })
      .then(function(data: any) {
        self._rows = data.rows || [];
        self._hasMore = data.has_more || false;
        self._sort = null;
        self._loading = false;
        self._paintData();
      })
      .catch(function() { self._loading = false; self._paintData(); });
    },

    _paintData: function(this: any) {
      var dz = this._rootEl!.querySelector('[data-pgv-data]');
      if (dz) {
        dz.innerHTML = this._tableHtml() + this._pagerHtml();
      }
      this._paintChips();
      this._bindData();
    },

    _filtersHtml: function(this: any): string {
      var cfg = this._cfg!;
      if (!cfg.filters || !cfg.filters.length) return '';
      var self = this;
      var inputs = cfg.filters.map(function(f: TableFilter) {
        if (f.type === 'select') {
          var opts = f.options!.map(function(o: [string, string]) {
            return '<option value="' + _esc(o[0]) + '">' + _esc(o[1]) + '</option>';
          }).join('');
          return '<select name="' + _esc(f.name) + '" data-label="' + _esc(f.label) + '">' + opts + '</select>';
        }
        var ph = f.label || self._t('table.search');
        return '<input type="search" name="' + _esc(f.name) + '" placeholder="' + _esc(ph) + '">';
      }).join('');
      return '<div class="pgv-filter"><div class="pgv-filter-bar"><div class="pgv-filter-inputs">' + inputs + '</div></div></div>';
    },

    _tableHtml: function(this: any): string {
      var cols = this._cfg!.cols || [];
      var rows = this._rows;
      var self = this;
      var thead = '<tr>' + cols.map(function(c: TableColumn, i: number) {
        var arrow = self._sort === i ? (self._sortDir === 'asc' ? ' &#9650;' : ' &#9660;') : '';
        return '<th class="pgv-sortable" data-sort-col="' + i + '">' + _esc(c.label) + arrow + '</th>';
      }).join('') + '</tr>';
      if (this._loading) {
        return '<div class="pgv-table"><table aria-busy="true"><thead>' + thead + '</thead><tbody><tr><td colspan="' + cols.length + '">' + _esc(this._t('table.loading')) + '</td></tr></tbody></table></div>';
      }
      if (!rows.length) {
        return '<div class="pgv-table"><table><thead>' + thead + '</thead></table></div><div class="pgv-empty">' + _esc(this._t('table.empty')) + '</div>';
      }
      var tbody = rows.map(function(row: any[]) {
        return '<tr>' + cols.map(function(c: TableColumn, i: number) {
          var val = row[i] != null ? row[i] : '';
          var cls = c['class'] || '';
          if (cls === 'pgv-col-link' && c.href) {
            var href = c.href.replace(/\{(\w+)\}/g, function(_: string, key: string) {
              var ci = cols.findIndex(function(cc: TableColumn) { return cc.key === key; });
              return ci >= 0 && row[ci] != null ? encodeURIComponent(row[ci]) : '';
            });
            return '<td><a href="' + _esc(href) + '">' + _esc(val) + '</a></td>';
          }
          if (cls === 'pgv-col-badge') {
            return '<td><span class="pgv-badge">' + _esc(val) + '</span></td>';
          }
          if (cls === 'pgv-col-date' && val) {
            var d = new Date(val);
            if (!isNaN(d.getTime())) val = ('0'+d.getDate()).slice(-2)+'/'+('0'+(d.getMonth()+1)).slice(-2)+' '+('0'+d.getHours()).slice(-2)+':'+('0'+d.getMinutes()).slice(-2);
            return '<td>' + _esc(val) + '</td>';
          }
          return '<td>' + _esc(String(val)) + '</td>';
        }).join('') + '</tr>';
      }).join('');
      return '<div class="pgv-table"><table><thead>' + thead + '</thead><tbody>' + tbody + '</tbody></table></div>';
    },

    _pagerHtml: function(this: any): string {
      if (this._loading || (!this._rows.length && this._offset === 0)) return '';
      var hasPrev = this._offset > 0;
      var hasNext = this._hasMore;
      if (!hasPrev && !hasNext) return '';
      return '<div class="pgv-pager"><span class="pgv-pager-btns">'
        + '<button data-prev' + (hasPrev ? '' : ' disabled') + '>&lsaquo; ' + _esc(this._t('table.prev')) + '</button>'
        + '<button data-next' + (hasNext ? '' : ' disabled') + '>' + _esc(this._t('table.next')) + ' &rsaquo;</button>'
        + '</span></div>';
    },

    _bindFilters: function(this: any) {
      var self = this;
      var el = this._rootEl!;
      el.querySelectorAll('.pgv-filter-inputs select').forEach(function(sel: any) {
        sel.addEventListener('change', function() {
          self._filters[sel.name] = sel.value; self._offset = 0; self._doFetch();
        });
      });
      var _timer: any;
      el.querySelectorAll('.pgv-filter-inputs input[type="search"]').forEach(function(inp: any) {
        inp.addEventListener('input', function() {
          clearTimeout(_timer);
          _timer = setTimeout(function() { self._filters[inp.name] = inp.value; self._offset = 0; self._doFetch(); }, 300);
        });
      });
    },

    _paintChips: function(this: any) {
      var cz = this._rootEl!.querySelector('[data-pgv-chips]');
      if (!cz) return;
      var self = this;
      var cfg = this._cfg!;
      var chips = '';
      var hasActive = false;
      (cfg.filters || []).forEach(function(f: TableFilter) {
        var val = self._filters[f.name];
        if (!val) return;
        hasActive = true;
        var dv = val;
        if (f.type === 'select') {
          var opt = f.options!.find(function(o: [string, string]) { return o[0] === val; });
          if (opt) dv = opt[1];
        }
        chips += '<span class="pgv-filter-chip"><span>' + _esc(f.label) + ': <strong>' + _esc(dv) + '</strong></span><button type="button" data-clear="' + _esc(f.name) + '">&times;</button></span>';
      });
      if (hasActive) chips += '<a href="#" class="pgv-filter-clear" data-clear-all>' + _esc(self._t('filter.clear')) + '</a>';
      cz.innerHTML = chips;
      cz.querySelectorAll('[data-clear]').forEach(function(btn: any) {
        btn.addEventListener('click', function(e: Event) {
          e.preventDefault(); self._filters[btn.dataset.clear] = ''; self._offset = 0;
          var inp = self._rootEl!.querySelector('[name="' + btn.dataset.clear + '"]') as HTMLInputElement | null;
          if (inp) inp.value = '';
          self._doFetch();
        });
      });
      var ca = cz.querySelector('[data-clear-all]');
      if (ca) ca.addEventListener('click', function(e: Event) {
        e.preventDefault();
        Object.keys(self._filters).forEach(function(k: string) { self._filters[k] = ''; });
        self._rootEl!.querySelectorAll('.pgv-filter-inputs input, .pgv-filter-inputs select').forEach(function(inp: any) { inp.value = ''; });
        self._offset = 0; self._doFetch();
      });
    },

    _bindData: function(this: any) {
      var self = this;
      var dz = this._rootEl!.querySelector('[data-pgv-data]');
      if (!dz) return;
      dz.querySelectorAll('[data-sort-col]').forEach(function(th: any) {
        th.addEventListener('click', function() {
          var idx = parseInt(th.dataset.sortCol);
          if (self._sort === idx) { self._sortDir = self._sortDir === 'asc' ? 'desc' : 'asc'; }
          else { self._sort = idx; self._sortDir = 'asc'; }
          self._sortRows();
          self._paintData();
        });
      });
      var prevBtn = dz.querySelector('[data-prev]');
      if (prevBtn) prevBtn.addEventListener('click', function() {
        self._offset = Math.max(0, self._offset - self._size); self._doFetch();
      });
      var nextBtn = dz.querySelector('[data-next]');
      if (nextBtn) nextBtn.addEventListener('click', function() {
        self._offset += self._size; self._doFetch();
      });
      dz.querySelectorAll('tbody tr').forEach(function(tr: HTMLTableRowElement) {
        var a = tr.querySelector('a[href^="/"]');
        if (!a) return;
        tr.style.cursor = 'pointer';
        tr.addEventListener('click', function(e: Event) {
          if ((e.target as Element).closest('a, button')) return;
          if (_goFn) _goFn(a!.getAttribute('href')!);
        });
      });
    },

    _sortRows: function(this: any) {
      var idx = this._sort, dir = this._sortDir === 'asc' ? 1 : -1;
      this._rows.sort(function(a: any[], b: any[]) {
        var va = a[idx!], vb = b[idx!];
        if (va == null) return dir;
        if (vb == null) return -dir;
        if (typeof va === 'number' && typeof vb === 'number') return (va - vb) * dir;
        return String(va).localeCompare(String(vb)) * dir;
      });
    }
  }; });
}
