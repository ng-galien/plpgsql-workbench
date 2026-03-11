/* ops.js — xterm.js terminal + Alpine.js component */

document.addEventListener('alpine:init', () => {
  Alpine.data('opsTerminal', () => ({
    term: null,
    ws: null,
    connected: false,

    init() {
      const container = this.$el;
      const el = this.$refs.terminal;
      if (!el) return;
      const module = el.dataset.module;
      const wsUrl = el.dataset.ws;
      if (!module || !wsUrl) return;

      // Apply data-height from server
      if (container.dataset.height) {
        container.style.height = container.dataset.height;
      }

      // IntersectionObserver: defer init if terminal is in a hidden tab
      if (!el.offsetParent) {
        const observer = new IntersectionObserver((entries) => {
          if (entries[0].isIntersecting) {
            observer.disconnect();
            this._initTerminal(el, wsUrl);
          }
        });
        observer.observe(el);
        return;
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
        const fitAddon = new FitAddon.FitAddon();
        this.term.loadAddon(fitAddon);
        this.term.open(el);
        fitAddon.fit();

        this.ws = new WebSocket(wsUrl);
        this.ws.onopen = () => { this.connected = true; };
        this.ws.onclose = () => { this.connected = false; };
        this.ws.onmessage = (e) => this.term.write(e.data);
        this.term.onData((data) => {
          if (this.ws?.readyState === 1) this.ws.send(data);
        });
        this.term.onResize(({ cols, rows }) => {
          if (this.ws?.readyState === 1)
            this.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
        });

        window.addEventListener('resize', () => fitAddon.fit());
      });
    },

    async loadXterm() {
      if (window.Terminal) return;
      await Promise.all([
        loadCSS('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/css/xterm.min.css'),
        loadScript('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/lib/xterm.min.js')
      ]);
      await loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0/lib/addon-fit.min.js');
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
