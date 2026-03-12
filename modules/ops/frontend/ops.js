/* ops.js — xterm.js terminal + Alpine.js component
 * Best practices from: claude-command-center, Codeman, VibeTunnel */

/* ── Constants ── */
const WS_RECONNECT_BASE = 1000;
const WS_RECONNECT_MAX  = 30000;
const WS_HEARTBEAT_MS   = 25000;     // expect data within this window
const RESIZE_DEBOUNCE    = 250;
const OUTPUT_FRAME_MAX   = 65536;    // 64KB per requestAnimationFrame flush
const BACKPRESSURE_LIMIT = 131072;   // 128KB pending → drop + schedule refresh

document.addEventListener('alpine:init', () => {
  Alpine.data('opsTerminal', (module) => ({
    term: null,
    ws: null,
    connected: false,

    init() {
      if (!module) return;
      const container = this.$el;
      const el = this.$refs.terminal;
      if (!el) return;
      this._wsUrl = `ws://${location.host}/ws/tmux/${module}`;

      if (container.dataset.height) {
        container.style.height = container.dataset.height;
      }

      this._reconnectAttempt = 0;
      this._reconnectTimer = null;
      this._heartbeatTimer = null;
      this._pendingWrites = [];
      this._writeFrameScheduled = false;
      this._destroyed = false;

      this._initTerminal(el);
    },

    destroy() {
      this._destroyed = true;
      clearTimeout(this._reconnectTimer);
      clearTimeout(this._heartbeatTimer);
      if (this.ws) { this.ws.onclose = null; this.ws.close(); }
      if (this.term) this.term.dispose();
    },

    /* ── Terminal setup ── */

    _initTerminal(el) {
      this.loadXterm().then(() => {
        this.term = new Terminal({
          cursorBlink: true,
          fontSize: 14,
          lineHeight: 1.2,
          scrollback: 10000,
          fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Monaco, Consolas, monospace',
          allowProposedApi: true,
          unicode: { activeVersion: '11' },
          theme: {
            background: '#1a1b26',
            foreground: '#a9b1d6',
            cursor: '#c0caf5',
            selectionBackground: '#33467c'
          }
        });

        this.fitAddon = new FitAddon.FitAddon();
        this.term.loadAddon(this.fitAddon);
        if (window.Unicode11Addon) {
          this.term.loadAddon(new Unicode11Addon.Unicode11Addon());
          this.term.unicode.activeVersion = '11';
        }
        if (window.WebLinksAddon) {
          this.term.loadAddon(new WebLinksAddon.WebLinksAddon());
        }
        this.term.open(el);

        // WebGL addon MUST be loaded after open() — needs DOM for GL context.
        // Handle context loss gracefully (browser limits ~16 GL contexts).
        if (window.WebglAddon) {
          try {
            const webgl = new WebglAddon.WebglAddon();
            webgl.onContextLoss(() => { webgl.dispose(); });
            this.term.loadAddon(webgl);
          } catch { /* fallback to canvas renderer */ }
        }

        requestAnimationFrame(() => {
          this.fitAddon.fit();
          this._connectWs();
        });

        // ResizeObserver — 250ms debounce (best practice from Codeman/VibeTunnel)
        let resizeTimer;
        this._resizeObserver = new ResizeObserver(() => {
          clearTimeout(resizeTimer);
          resizeTimer = setTimeout(() => {
            this.fitAddon.fit();
          }, RESIZE_DEBOUNCE);
        });
        this._resizeObserver.observe(el);

        // Forward resize to server
        this.term.onResize(({ cols, rows }) => {
          if (this.ws?.readyState === 1) {
            this.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
          }
        });

        // Input → WS with coalescing (50ms gap = flush)
        this._inputBuffer = '';
        this._inputFlushTimer = null;
        this.term.onData((data) => {
          if (this.ws?.readyState !== 1) return;
          this._inputBuffer += data;
          clearTimeout(this._inputFlushTimer);
          this._inputFlushTimer = setTimeout(() => this._flushInput(), 0);
        });
      });
    },

    _flushInput() {
      if (this._inputBuffer && this.ws?.readyState === 1) {
        this.ws.send(this._inputBuffer);
        this._inputBuffer = '';
      }
    },

    /* ── WebSocket with reconnection ── */

    _connectWs() {
      if (this._destroyed) return;

      const ws = new WebSocket(this._wsUrl);
      this.ws = ws;

      ws.onopen = () => {
        this.connected = true;
        this._reconnectAttempt = 0;
        this._updateParent('_connected', true);
        this._updateParent('_disconnected', false);
        this._resetHeartbeat();

        // CRITICAL: send initial dimensions immediately — server needs them before scrollback
        const cols = this.term.cols;
        const rows = this.term.rows;
        ws.send(JSON.stringify({ type: 'resize', cols, rows }));

        // On reconnect: clear stale content + force tmux repaint via resize toggle
        if (this._wasConnected) {
          this.term.clear();
          setTimeout(() => {
            if (ws.readyState !== 1) return;
            ws.send(JSON.stringify({ type: 'resize', cols: cols + 1, rows }));
            ws.send(JSON.stringify({ type: 'resize', cols, rows }));
          }, 100);
        }
        this._wasConnected = true;
      };

      ws.onclose = () => {
        this.connected = false;
        this._updateParent('_connected', false);
        this._updateParent('_disconnected', true);
        clearTimeout(this._heartbeatTimer);
        this._scheduleReconnect();
      };

      ws.onerror = () => {}; // onclose will fire

      // Output batching: accumulate chunks, flush per requestAnimationFrame (Codeman pattern)
      ws.onmessage = (e) => {
        this._resetHeartbeat();

        // Client-side backpressure: drop if queue > 128KB, schedule full refresh
        const queued = this._pendingWrites.reduce((s, w) => s + w.length, 0);
        if (queued > BACKPRESSURE_LIMIT) {
          if (!this._dropRecoveryTimer) {
            this._dropRecoveryTimer = setTimeout(() => {
              this._dropRecoveryTimer = null;
              this.term.clear();
              // Re-request scrollback by reconnecting
              this._reconnectNow();
            }, 2000);
          }
          return;
        }

        this._pendingWrites.push(e.data);
        if (!this._writeFrameScheduled) {
          this._writeFrameScheduled = true;
          requestAnimationFrame(() => this._flushPendingWrites());
        }
      };
    },

    _flushPendingWrites() {
      this._writeFrameScheduled = false;
      if (!this._pendingWrites.length || !this.term) return;

      const joined = this._pendingWrites.join('');
      this._pendingWrites = [];

      // Cap per-frame write at 64KB (Codeman pattern)
      if (joined.length <= OUTPUT_FRAME_MAX) {
        this.term.write(joined);
      } else {
        this.term.write(joined.slice(0, OUTPUT_FRAME_MAX));
        this._pendingWrites.push(joined.slice(OUTPUT_FRAME_MAX));
        requestAnimationFrame(() => this._flushPendingWrites());
      }
    },

    /* ── Reconnection: exponential backoff + jitter, never give up ── */

    _scheduleReconnect() {
      if (this._destroyed) return;
      const delay = Math.min(WS_RECONNECT_BASE * Math.pow(2, this._reconnectAttempt), WS_RECONNECT_MAX);
      const jitter = delay * (0.5 + Math.random() * 0.5);
      this._reconnectAttempt++;
      this._reconnectTimer = setTimeout(() => this._connectWs(), jitter);
    },

    _reconnectNow() {
      if (this.ws) { this.ws.onclose = null; this.ws.close(); }
      this._connectWs();
    },

    /* ── Heartbeat: detect zombie connections ── */

    _resetHeartbeat() {
      clearTimeout(this._heartbeatTimer);
      this._heartbeatTimer = setTimeout(() => {
        // No data received within window → connection likely dead
        if (this.ws?.readyState === 1) {
          this.ws.close();
        }
      }, WS_HEARTBEAT_MS);
    },

    /* ── Helpers ── */

    _updateParent(key, value) {
      try {
        const grid = Alpine.closestDataStack(this.$el).find(d => d.sessions);
        if (grid) {
          const s = grid.sessions.find(s => s.name === module);
          if (s) s[key] = value;
        }
      } catch {}
    },

    loadXterm() {
      if (!window._xtermLoading) {
        window._xtermLoading = Promise.all([
          loadCSS('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/css/xterm.min.css'),
          loadScript('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/lib/xterm.min.js')
        ]).then(() => Promise.all([
          loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0/lib/addon-fit.min.js'),
          loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-unicode11@0/lib/addon-unicode11.min.js').catch(() => {}),
          loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-webgl@0/lib/addon-webgl.min.js').catch(() => {}),
          loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0/lib/addon-web-links.min.js').catch(() => {}),
        ]));
      }
      return window._xtermLoading;
    }
  }));

  // Live tmux grid — fetches active tmux sessions and renders terminal cards
  Alpine.data('opsTmuxGrid', () => ({
    sessions: [],
    loading: true,

    init() {
      this.refresh();
      this._interval = setInterval(() => this.refresh(), 10000);
    },

    destroy() {
      clearInterval(this._interval);
    },

    trigResize() {
      document.querySelectorAll('.ops-terminal').forEach(el => {
        const comp = Alpine.$data(el);
        if (comp?.fitAddon) comp.fitAddon.fit();
      });
    },

    scrollBottom() {
      document.querySelectorAll('.ops-terminal').forEach(el => {
        const comp = Alpine.$data(el);
        if (comp?.term) comp.term.scrollToBottom();
      });
    },

    pingAll() {
      document.querySelectorAll('.ops-terminal').forEach(el => {
        const comp = Alpine.$data(el);
        if (comp?.ws?.readyState === 1) {
          comp.ws.send('Ping\r');
        }
      });
    },

    async refresh() {
      try {
        const res = await fetch('/api/tmux');
        if (!res.ok) { this.loading = false; return; }
        const data = await res.json();
        const list = Array.isArray(data) ? data : (data.sessions || []);
        const newNames = list.map(s => s.name);
        const oldNames = this.sessions.map(s => s.name);
        if (JSON.stringify(newNames) !== JSON.stringify(oldNames)) {
          this.sessions = list;
        }
      } catch { /* ignore */ }
      this.loading = false;
    }
  }));
});

function loadScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const s = document.createElement('script');
    s.src = src; s.onload = resolve; s.onerror = reject;
    document.head.appendChild(s);
  });
}

function loadCSS(href) {
  return new Promise((resolve) => {
    if (document.querySelector(`link[href="${href}"]`)) return resolve();
    const l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = href; l.onload = resolve;
    document.head.appendChild(l);
  });
}
