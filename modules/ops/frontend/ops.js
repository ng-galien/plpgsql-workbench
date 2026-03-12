/* ops.js — xterm.js terminal + Alpine.js component */

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
      const wsUrl = `ws://${location.host}/ws/tmux/${module}`;

      // Apply data-height from server
      if (container.dataset.height) {
        container.style.height = container.dataset.height;
      }

      this._initTerminal(el, wsUrl);
    },

    _initTerminal(el, wsUrl) {
      this.loadXterm().then(() => {
        this.term = new Terminal({
          cursorBlink: true,
          fontSize: 13,
          fontFamily: 'Menlo, Monaco, "Courier New", monospace',
          theme: {
            background: '#1a1b26',
            foreground: '#a9b1d6',
            cursor: '#c0caf5',
            selectionBackground: '#33467c'
          }
        });
        this.fitAddon = new FitAddon.FitAddon();
        this.term.loadAddon(this.fitAddon);
        this.term.open(el);

        // Delay fit until layout is stable
        requestAnimationFrame(() => {
          this.fitAddon.fit();
          // Connect WS only after first fit so server gets correct cols/rows
          this._connectWs(wsUrl);
        });

        // Debounced ResizeObserver to avoid fit() spam
        let resizeTimer;
        new ResizeObserver(() => {
          clearTimeout(resizeTimer);
          resizeTimer = setTimeout(() => this.fitAddon.fit(), 100);
        }).observe(el);
      });
    },

    _connectWs(wsUrl) {
        this.ws = new WebSocket(wsUrl);
        this.ws.onopen = () => {
          this.connected = true;
          this._updateParent('_connected', true);
          this._updateParent('_disconnected', false);
        };
        this.ws.onclose = () => {
          this.connected = false;
          this._updateParent('_connected', false);
          this._updateParent('_disconnected', true);
        };
        this.ws.onmessage = (e) => this.term.write(e.data);
        this.term.onData((data) => {
          if (this.ws?.readyState === 1) this.ws.send(data);
        });
        this.term.onResize(({ cols, rows }) => {
          if (this.ws?.readyState === 1)
            this.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
        });
    },

    _updateParent(key, value) {
      // Walk up Alpine scopes to find the session object in opsTmuxGrid
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
        ]).then(() => loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0/lib/addon-fit.min.js'));
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
      // Send "Ping" + Enter to each agent's tmux session via WebSocket
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
        // Only update if sessions changed
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
