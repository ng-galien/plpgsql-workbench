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
  if (s == null) return "";
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
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

/** Response shape from the table RPC */
interface TableRpcResponse {
  rows?: unknown[][];
  has_more?: boolean;
}

/** Alpine component instance for pgvTable */
interface TableComponent {
  /** Alpine magic: root element */
  $el: HTMLElement;
  /** Alpine magic: named $refs */
  $refs: Record<string, HTMLElement>;
  /** Alpine magic: defer to next DOM update tick */
  $nextTick: (cb: () => void) => void;

  _cfg: TableConfig | null;
  _rows: unknown[][];
  _offset: number;
  _size: number;
  _hasMore: boolean;
  _sort: number | null;
  _sortDir: "asc" | "desc";
  _filters: Record<string, string>;
  _loading: boolean;
  _rootEl: HTMLElement | null;

  _t(key: string): string;
  init(): void;
  _doFetch(): void;
  _paintData(): void;
  _filtersHtml(): string;
  _tableHtml(): string;
  _pagerHtml(): string;
  _bindFilters(): void;
  _paintChips(): void;
  _bindData(): void;
  _sortRows(): void;
}

/** Navigate callback — the shell provides its go() function */
export type GoFn = (path: string) => void;

let _goFn: GoFn | null = null;

/** Set the navigation function used by pgvTable row clicks */
export function setTableGoFn(fn: GoFn): void {
  _goFn = fn;
}

/** Register the pgvTable Alpine component */
export function registerTable(Alpine: AlpineStatic): void {
  Alpine.data("pgvTable", function (this: TableComponent) {
    return {
      _cfg: null as TableConfig | null,
      _rows: [] as unknown[][],
      _offset: 0,
      _size: 20,
      _hasMore: false,
      _sort: null as number | null,
      _sortDir: "asc" as "asc" | "desc",
      _filters: {} as Record<string, string>,
      _loading: true,
      _rootEl: null as HTMLElement | null,

      _t: (key: string): string => t(key),

      init: function (this: TableComponent) {
        this._rootEl = this.$el;
        this._cfg = JSON.parse(this._rootEl.dataset.config ?? "null");
        this._size = this._cfg?.page_size || 20;

        (this._cfg?.filters || []).forEach((f: TableFilter) => {
          this._filters[f.name] = "";
        });
        // Stable filter bar + dynamic data zone
        const rootEl = this._rootEl;
        if (!rootEl) return;
        rootEl.innerHTML = `${this._filtersHtml()}<div data-pgv-chips></div><div data-pgv-data></div>`;
        this._bindFilters();
        this._doFetch();
      },

      _doFetch: function (this: TableComponent) {
        var cfg = getConfig();
        this._loading = true;
        this._paintData();
        var p: Record<string, unknown> = {};
        Object.keys(this._filters).forEach((k: string) => {
          if (this._filters[k]) p[k] = this._filters[k];
        });
        p._offset = this._offset;
        p._size = this._size;
        const tableCfg = this._cfg;
        if (!tableCfg) return;
        fetch(cfg.rpc("/") + tableCfg.rpc, {
          method: "POST",
          headers: cfg.headers("application/json", tableCfg.schema),
          body: JSON.stringify({ p_params: p }),
        })
          .then((r: Response) => r.json())
          .then((data: TableRpcResponse) => {
            this._rows = data.rows || [];
            this._hasMore = data.has_more || false;
            this._sort = null;
            this._loading = false;
            this._paintData();
          })
          .catch(() => {
            this._loading = false;
            this._paintData();
          });
      },

      _paintData: function (this: TableComponent) {
        var dz = this._rootEl?.querySelector("[data-pgv-data]");
        if (dz) {
          dz.innerHTML = this._tableHtml() + this._pagerHtml();
        }
        this._paintChips();
        this._bindData();
      },

      _filtersHtml: function (this: TableComponent): string {
        const cfg = this._cfg;
        if (!cfg || !cfg.filters || !cfg.filters.length) return "";

        var inputs = cfg.filters
          .map((f: TableFilter) => {
            if (f.type === "select") {
              const opts = (f.options || [])
                .map((o: [string, string]) => `<option value="${_esc(o[0])}">${_esc(o[1])}</option>`)
                .join("");
              return `<select name="${_esc(f.name)}" data-label="${_esc(f.label)}">${opts}</select>`;
            }
            var ph = f.label || this._t("table.search");
            return `<input type="search" name="${_esc(f.name)}" placeholder="${_esc(ph)}">`;
          })
          .join("");
        return (
          '<div class="pgv-filter"><div class="pgv-filter-bar"><div class="pgv-filter-inputs">' +
          inputs +
          "</div></div></div>"
        );
      },

      _tableHtml: function (this: TableComponent): string {
        var cols = this._cfg?.cols || [];
        var rows = this._rows;

        var thead =
          "<tr>" +
          cols
            .map((c: TableColumn, i: number) => {
              var arrow = this._sort === i ? (this._sortDir === "asc" ? " &#9650;" : " &#9660;") : "";
              return `<th class="pgv-sortable" data-sort-col="${i}">${_esc(c.label)}${arrow}</th>`;
            })
            .join("") +
          "</tr>";
        if (this._loading) {
          return (
            '<div class="pgv-table"><table aria-busy="true"><thead>' +
            thead +
            '</thead><tbody><tr><td colspan="' +
            cols.length +
            '">' +
            _esc(this._t("table.loading")) +
            "</td></tr></tbody></table></div>"
          );
        }
        if (!rows.length) {
          return (
            '<div class="pgv-table"><table><thead>' +
            thead +
            '</thead></table></div><div class="pgv-empty">' +
            _esc(this._t("table.empty")) +
            "</div>"
          );
        }
        var tbody = rows
          .map(
            (row: unknown[]) =>
              "<tr>" +
              cols
                .map((c: TableColumn, i: number) => {
                  var val = row[i] != null ? row[i] : "";
                  var cls = c.class || "";
                  if (cls === "pgv-col-link" && c.href) {
                    const href = c.href.replace(/\{(\w+)\}/g, (_: string, key: string) => {
                      const ci = cols.findIndex((cc: TableColumn) => cc.key === key);
                      return ci >= 0 && row[ci] != null ? encodeURIComponent(String(row[ci])) : "";
                    });
                    return `<td><a href="${_esc(href)}">${_esc(val)}</a></td>`;
                  }
                  if (cls === "pgv-col-badge") {
                    return `<td><span class="pgv-badge">${_esc(val)}</span></td>`;
                  }
                  if (cls === "pgv-col-date" && val) {
                    const d = new Date(val as string | number);
                    if (!Number.isNaN(d.getTime()))
                      val =
                        `0${d.getDate()}`.slice(-2) +
                        "/" +
                        `0${d.getMonth() + 1}`.slice(-2) +
                        " " +
                        `0${d.getHours()}`.slice(-2) +
                        ":" +
                        `0${d.getMinutes()}`.slice(-2);
                    return `<td>${_esc(val)}</td>`;
                  }
                  return `<td>${_esc(String(val))}</td>`;
                })
                .join("") +
              "</tr>",
          )
          .join("");
        return `<div class="pgv-table"><table><thead>${thead}</thead><tbody>${tbody}</tbody></table></div>`;
      },

      _pagerHtml: function (this: TableComponent): string {
        if (this._loading || (!this._rows.length && this._offset === 0)) return "";
        var hasPrev = this._offset > 0;
        var hasNext = this._hasMore;
        if (!hasPrev && !hasNext) return "";
        return (
          '<div class="pgv-pager"><span class="pgv-pager-btns">' +
          "<button data-prev" +
          (hasPrev ? "" : " disabled") +
          ">&lsaquo; " +
          _esc(this._t("table.prev")) +
          "</button>" +
          "<button data-next" +
          (hasNext ? "" : " disabled") +
          ">" +
          _esc(this._t("table.next")) +
          " &rsaquo;</button>" +
          "</span></div>"
        );
      },

      _bindFilters: function (this: TableComponent) {
        const el = this._rootEl;
        if (!el) return;
        el.querySelectorAll<HTMLSelectElement>(".pgv-filter-inputs select").forEach((sel) => {
          sel.addEventListener("change", () => {
            this._filters[sel.name] = sel.value;
            this._offset = 0;
            this._doFetch();
          });
        });
        var _timer: ReturnType<typeof setTimeout> | undefined;
        el.querySelectorAll<HTMLInputElement>('.pgv-filter-inputs input[type="search"]').forEach((inp) => {
          inp.addEventListener("input", () => {
            clearTimeout(_timer);
            _timer = setTimeout(() => {
              this._filters[inp.name] = inp.value;
              this._offset = 0;
              this._doFetch();
            }, 300);
          });
        });
      },

      _paintChips: function (this: TableComponent) {
        var cz = this._rootEl?.querySelector("[data-pgv-chips]");
        if (!cz) return;

        const cfg = this._cfg;
        if (!cfg) return;
        var chips = "";
        var hasActive = false;
        (cfg.filters || []).forEach((f: TableFilter) => {
          var val = this._filters[f.name];
          if (!val) return;
          hasActive = true;
          var dv = val;
          if (f.type === "select") {
            const opt = (f.options || []).find((o: [string, string]) => o[0] === val);
            if (opt) dv = opt[1];
          }
          chips +=
            '<span class="pgv-filter-chip"><span>' +
            _esc(f.label) +
            ": <strong>" +
            _esc(dv) +
            '</strong></span><button type="button" data-clear="' +
            _esc(f.name) +
            '">&times;</button></span>';
        });
        if (hasActive)
          chips += `<a href="#" class="pgv-filter-clear" data-clear-all>${_esc(this._t("filter.clear"))}</a>`;
        cz.innerHTML = chips;
        cz.querySelectorAll<HTMLElement>("[data-clear]").forEach((btn) => {
          btn.addEventListener("click", (e: Event) => {
            e.preventDefault();
            const clearName = btn.dataset.clear;
            if (clearName) {
              this._filters[clearName] = "";
              const inp = this._rootEl?.querySelector<HTMLInputElement>(`[name="${clearName}"]`);
              if (inp) inp.value = "";
            }
            this._offset = 0;
            this._doFetch();
          });
        });
        var ca = cz.querySelector("[data-clear-all]");
        if (ca)
          ca.addEventListener("click", (e: Event) => {
            e.preventDefault();
            Object.keys(this._filters).forEach((k: string) => {
              this._filters[k] = "";
            });
            this._rootEl
              ?.querySelectorAll<HTMLInputElement | HTMLSelectElement>(
                ".pgv-filter-inputs input, .pgv-filter-inputs select",
              )
              .forEach((inp) => {
                inp.value = "";
              });
            this._offset = 0;
            this._doFetch();
          });
      },

      _bindData: function (this: TableComponent) {
        var dz = this._rootEl?.querySelector("[data-pgv-data]");
        if (!dz) return;
        dz.querySelectorAll<HTMLElement>("[data-sort-col]").forEach((th) => {
          th.addEventListener("click", () => {
            var idx = parseInt(th.dataset.sortCol || "0", 10);
            if (this._sort === idx) {
              this._sortDir = this._sortDir === "asc" ? "desc" : "asc";
            } else {
              this._sort = idx;
              this._sortDir = "asc";
            }
            this._sortRows();
            this._paintData();
          });
        });
        var prevBtn = dz.querySelector("[data-prev]");
        if (prevBtn)
          prevBtn.addEventListener("click", () => {
            this._offset = Math.max(0, this._offset - this._size);
            this._doFetch();
          });
        var nextBtn = dz.querySelector("[data-next]");
        if (nextBtn)
          nextBtn.addEventListener("click", () => {
            this._offset += this._size;
            this._doFetch();
          });
        dz.querySelectorAll("tbody tr").forEach((tr: Element) => {
          const anchor = tr.querySelector('a[href^="/"]');
          if (!anchor) return;
          const anchorHref = anchor.getAttribute("href");
          if (!anchorHref) return;
          (tr as HTMLElement).style.cursor = "pointer";
          tr.addEventListener("click", (e: Event) => {
            if ((e.target as Element).closest("a, button")) return;
            if (_goFn) _goFn(anchorHref);
          });
        });
      },

      _sortRows: function (this: TableComponent) {
        var idx = this._sort;
        if (idx == null) return;
        var dir = this._sortDir === "asc" ? 1 : -1;
        var sortIdx = idx;
        this._rows.sort((a: unknown[], b: unknown[]) => {
          var va = a[sortIdx],
            vb = b[sortIdx];
          if (va == null) return dir;
          if (vb == null) return -dir;
          if (typeof va === "number" && typeof vb === "number") return (va - vb) * dir;
          return String(va).localeCompare(String(vb)) * dir;
        });
      },
    };
  });
}
