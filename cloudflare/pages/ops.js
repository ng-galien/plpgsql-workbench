/* ops.js — xterm.js terminal + Alpine.js components
 * Single-terminal pattern (Codeman): one xterm instance, buffer cache for inactive sessions.
 * opsTerminal: standalone component for detail view (get_agent). */

/* ── Constants ── */
const WS_RECONNECT_BASE    = 1000;
const WS_RECONNECT_MAX     = 30000;
const WS_HEARTBEAT_MS      = 25000;
const RESIZE_DEBOUNCE      = 250;
const OUTPUT_FRAME_MAX     = 65536;     // 64KB per rAF flush
const BACKPRESSURE_LIMIT   = 131072;    // 128KB pending → drop + schedule refresh
const BUFFER_RESTORE_CHUNK = 131072;    // 128KB per rAF during buffer restore
const MAX_BUFFER_CACHE     = 20;
const MAX_BUFFER_SIZE      = 5242880;   // 5MB max per session buffer
const WS_MAX_RECONNECT     = 5;         // max attempts before giving up

/* ── Theme ── */
const THEME_DARK  = { background: '#1a1b26', foreground: '#a9b1d6', cursor: '#c0caf5', selectionBackground: '#33467c' };
const THEME_LIGHT = { background: '#f8f8f2', foreground: '#383a42', cursor: '#526fff', selectionBackground: '#d0d0d0' };

function xtermTheme() {
  return document.documentElement.getAttribute('data-theme') === 'light' ? THEME_LIGHT : THEME_DARK;
}

document.addEventListener('alpine:init', () => {
  console.log('[OPS] alpine:init fired');

  /* ══════════════════════════════════════════════════════════════════
   * opsTmuxGrid — owns the SINGLE xterm.js instance for the grid view.
   * Each open card shares this terminal; buffer cache preserves output
   * when switching between sessions. Only 1 WebGL context ever created.
   * ══════════════════════════════════════════════════════════════════ */
  Alpine.data('opsTmuxGrid', () => ({
    sessions: [],
    loading: true,
    activeModule: null,

    /* Private */
    _term: null,
    _fitAddon: null,
    _xtermReady: false,
    _xtermLoading: null,
    _resizeObs: null,
    _resizeTimer: null,
    _themeObs: null,
    _inputBuffer: '',
    _inputTimer: null,
    _interval: null,
    _bufferCache: new Map(),    // mod → raw output string
    _connections: new Map(),    // mod → connection object

    /* Buffer restore state */
    _restoring: false,
    _restoreQueue: [],

    _pendingActivation: null,
    _rootEl: null,

    init() {
      this._rootEl = this.$el;  // Capture root — $el is context-dependent in Alpine
      console.log('[OPS:grid] init() — rootEl:', this._rootEl?.tagName, this._rootEl?.className);
      this.refresh();
      this._interval = setInterval(() => this.refresh(), 3000);
      this._themeObs = new MutationObserver(() => {
        if (this._term) this._term.options.theme = xtermTheme();
      });
      this._themeObs.observe(document.documentElement, {
        attributes: true, attributeFilter: ['data-theme']
      });
      // Eagerly load xterm libs so activateSession can be synchronous
      _loadXtermLibs().then(() => {
        console.log('[OPS:grid] xterm libs loaded, calling _createTerminal()');
        this._createTerminal();
      }).catch(err => {
        console.error('[OPS:grid] xterm libs FAILED to load', err);
      });
    },

    destroy() {
      console.log('[OPS:grid] destroy()');
      clearInterval(this._interval);
      this._themeObs?.disconnect();
      this._resizeObs?.disconnect();
      clearTimeout(this._resizeTimer);
      clearTimeout(this._inputTimer);
      for (const conn of this._connections.values()) this._destroyConn(conn);
      this._connections.clear();
      if (this._term) this._term.dispose();
    },

    /* ── xterm.js creation (called once after libs load) ── */

    _createTerminal() {
      console.log('[OPS:grid] _createTerminal() — Terminal class:', typeof Terminal);
      this._term = new Terminal({
        cursorBlink: true,
        fontSize: 14,
        lineHeight: 1.2,
        scrollback: 10000,
        fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Monaco, Consolas, monospace',
        allowProposedApi: true,
        unicode: { activeVersion: '11' },
        theme: xtermTheme()
      });
      console.log('[OPS:grid] Terminal instance created:', !!this._term);

      this._fitAddon = new FitAddon.FitAddon();
      this._term.loadAddon(this._fitAddon);
      if (window.Unicode11Addon) {
        this._term.loadAddon(new Unicode11Addon.Unicode11Addon());
        this._term.unicode.activeVersion = '11';
      }
      if (window.WebLinksAddon) {
        this._term.loadAddon(new WebLinksAddon.WebLinksAddon());
      }
      console.log('[OPS:grid] Addons loaded — FitAddon:', !!this._fitAddon, 'Unicode11:', !!window.Unicode11Addon, 'WebGL:', !!window.WebglAddon, 'WebLinks:', !!window.WebLinksAddon);

      // Forward keyboard input to active WS
      this._term.onData((data) => {
        const conn = this.activeModule && this._connections.get(this.activeModule);
        if (!conn?.ws || conn.ws.readyState !== 1) return;
        this._inputBuffer += data;
        clearTimeout(this._inputTimer);
        this._inputTimer = setTimeout(() => {
          if (this._inputBuffer && conn.ws?.readyState === 1) {
            conn.ws.send(this._inputBuffer);
            this._inputBuffer = '';
          }
        }, 0);
      });

      // Forward resize to active WS
      this._term.onResize(({ cols, rows }) => {
        console.log('[OPS:grid] term.onResize', cols, 'x', rows, 'active:', this.activeModule);
        const conn = this.activeModule && this._connections.get(this.activeModule);
        if (conn?.ws?.readyState === 1) {
          conn.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
        }
      });

      this._xtermReady = true;
      console.log('[OPS:grid] _xtermReady = true, pendingActivation:', this._pendingActivation);

      // Process pending activation (user clicked before libs loaded)
      if (this._pendingActivation) {
        const pending = this._pendingActivation;
        this._pendingActivation = null;
        if (this.activeModule === pending) {
          console.log('[OPS:grid] processing pending activation:', pending);
          this.$nextTick(() => this._doActivate(pending));
        } else {
          console.log('[OPS:grid] pending activation stale — activeModule:', this.activeModule, 'pending:', pending);
        }
      }
    },

    /* ── Session activation — fully synchronous, no async/await ── */

    activateSession(mod) {
      console.log('[OPS:grid] activateSession()', mod, '— current active:', this.activeModule, 'xtermReady:', this._xtermReady);
      // If re-clicking the same module after gave-up, retry connection
      if (this.activeModule === mod) {
        const conn = this._connections.get(mod);
        if (conn && conn.attempt > WS_MAX_RECONNECT) {
          console.log('[OPS:grid] activateSession() — retrying gave-up connection for', mod);
          conn.attempt = 0;
          this._setState(mod, { _gaveUp: false, _reconnecting: true });
          this._connectWs(mod, conn);
        } else {
          console.log('[OPS:grid] activateSession() — already active, skip');
        }
        return;
      }
      this.activeModule = mod;

      if (!this._xtermReady) {
        // Libs still loading — defer until _createTerminal runs
        console.log('[OPS:grid] activateSession() — xterm not ready, deferring');
        this._pendingActivation = mod;
        return;
      }

      // $nextTick: wait for Alpine to render x-if="activeModule" template
      this.$nextTick(() => this._doActivate(mod));
    },

    _doActivate(mod) {
      console.log('[OPS:grid] _doActivate()', mod, '— rootEl:', this._rootEl?.tagName);
      const container = this._rootEl.querySelector(`[data-terminal-for="${mod}"]`);
      console.log('[OPS:grid] _doActivate() — container:', container ? `${container.tagName}.${container.className} ${container.offsetWidth}x${container.offsetHeight}` : 'NOT FOUND');
      if (!container) return;

      // First open: term.open(). Subsequent: move DOM.
      if (!this._term.element) {
        console.log('[OPS:grid] _doActivate() — first open: term.open(container)');
        this._term.open(container);
        console.log('[OPS:grid] _doActivate() — term.element after open():', !!this._term.element, 'term.element.offsetHeight:', this._term.element?.offsetHeight);
        // WebGL addon MUST load after open() — needs DOM for GL context
        if (window.WebglAddon) {
          try {
            const webgl = new WebglAddon.WebglAddon();
            webgl.onContextLoss(() => { try { webgl.dispose(); } catch {} });
            this._term.loadAddon(webgl);
            console.log('[OPS:grid] WebGL addon loaded');
          } catch (e) {
            console.warn('[OPS:grid] WebGL addon failed, fallback to canvas', e);
          }
        }
      } else {
        console.log('[OPS:grid] _doActivate() — move DOM: appendChild(term.element)');
        container.appendChild(this._term.element);
      }

      // Clear + double-frame fit (robuste: waits for layout)
      this._term.clear();
      this._term.reset();

      // Ensure WS connection early (before fit — data buffers while we wait)
      this._ensureConn(mod);

      // ResizeObserver on new container
      this._resizeObs?.disconnect();
      this._resizeObs = new ResizeObserver(() => {
        clearTimeout(this._resizeTimer);
        this._resizeTimer = setTimeout(() => {
          if (this._fitAddon && this.activeModule === mod) this._fitAddon.fit();
        }, RESIZE_DEBOUNCE);
      });
      this._resizeObs.observe(container);

      // Double-rAF: fit first, THEN restore buffer at correct column count
      console.log('[OPS:grid] _doActivate() — scheduling double-rAF fit');
      requestAnimationFrame(() => requestAnimationFrame(() => {
        if (!this._fitAddon || this.activeModule !== mod) {
          console.log('[OPS:grid] double-rAF — aborted (fitAddon:', !!this._fitAddon, 'activeModule:', this.activeModule, 'expected:', mod, ')');
          return;
        }
        console.log('[OPS:grid] double-rAF — fitting. Container size:', container.offsetWidth, 'x', container.offsetHeight);
        this._fitAddon.fit();
        console.log('[OPS:grid] double-rAF — fit done. Terminal size:', this._term.cols, 'x', this._term.rows);
        this._term.write('\x1b[3J');  // clean scrollback artifacts
        this._restoreBuffer(mod);

        // Send dimensions after restore settles
        setTimeout(() => {
          const conn = this._connections.get(mod);
          if (conn?.ws?.readyState === 1 && this._term) {
            console.log('[OPS:grid] sending resize to server:', this._term.cols, 'x', this._term.rows);
            conn.ws.send(JSON.stringify({ type: 'resize', cols: this._term.cols, rows: this._term.rows }));
          }
        }, 50);
      }));
    },

    deactivateSession(mod) {
      if (this.activeModule !== mod) return;
      console.log('[OPS:grid] deactivateSession()', mod);
      this.activeModule = null;
      // WS stays alive — keeps buffering in background
    },

    _restoreBuffer(mod) {
      const buf = this._bufferCache.get(mod);
      console.log('[OPS:grid] _restoreBuffer()', mod, '— bufferSize:', buf?.length ?? 0);
      if (!buf || !this._term) return;

      this._restoring = true;
      this._restoreQueue = [];
      let offset = 0;

      const writeChunk = () => {
        if (!this._term || this.activeModule !== mod) {
          this._restoring = false;
          this._drainRestoreQueue();
          return;
        }
        const chunk = buf.slice(offset, offset + BUFFER_RESTORE_CHUNK);
        if (!chunk.length) {
          this._restoring = false;
          this._drainRestoreQueue();
          return;
        }
        this._term.write(chunk);
        offset += chunk.length;
        if (offset < buf.length) requestAnimationFrame(writeChunk);
        else { this._restoring = false; this._drainRestoreQueue(); }
      };
      requestAnimationFrame(writeChunk);
    },

    _drainRestoreQueue() {
      if (!this._term || !this._restoreQueue.length) return;
      this._term.write(this._restoreQueue.join(''));
      this._restoreQueue = [];
    },

    /* ── WebSocket connection management ── */

    _ensureConn(mod) {
      if (this._connections.has(mod)) {
        console.log('[OPS:grid] _ensureConn() — already exists for', mod);
        return;
      }
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      const conn = {
        ws: null,
        url: `${proto}://${location.host}/ws/tmux/${mod}`,
        attempt: 0,
        reconnectTimer: null,
        heartbeatTimer: null,
        dropTimer: null,
        pending: [],
        frameScheduled: false,
        wasConnected: false,
        destroyed: false
      };
      this._connections.set(mod, conn);
      console.log('[OPS:grid] _ensureConn() — creating WS for', mod, 'url:', conn.url);
      this._connectWs(mod, conn);
    },

    _connectWs(mod, conn) {
      if (conn.destroyed) return;
      console.log('[OPS:grid] _connectWs()', mod, 'url:', conn.url);
      const ws = new WebSocket(conn.url);
      conn.ws = ws;

      ws.onopen = () => {
        console.log('[OPS:grid] WS onopen', mod);
        conn.attempt = 0;
        this._resetHeartbeat(conn);
        this._setState(mod, { _connected: true, _disconnected: false, _reconnecting: false });

        // Send initial dimensions if this is the active terminal
        if (this._term && this.activeModule === mod) {
          console.log('[OPS:grid] WS onopen — sending initial resize:', this._term.cols, 'x', this._term.rows);
          ws.send(JSON.stringify({ type: 'resize', cols: this._term.cols, rows: this._term.rows }));
        }

        // On reconnect: force tmux repaint via resize toggle
        if (conn.wasConnected && this.activeModule === mod && this._term) {
          this._term.clear();
          setTimeout(() => {
            if (ws.readyState !== 1 || !this._term) return;
            const { cols, rows } = this._term;
            ws.send(JSON.stringify({ type: 'resize', cols: cols + 1, rows }));
            ws.send(JSON.stringify({ type: 'resize', cols, rows }));
          }, 100);
        }
        conn.wasConnected = true;
      };

      ws.onclose = (e) => {
        console.log('[OPS:grid] WS onclose', mod, 'code:', e.code, 'reason:', e.reason);
        clearTimeout(conn.heartbeatTimer);
        this._setState(mod, { _connected: false, _disconnected: true });
        // Show error in terminal if this is the active session
        if (this._term && this.activeModule === mod) {
          const reason = e.reason || (e.code === 1006 ? 'connexion perdue' : '');
          this._term.write(`\r\n\x1b[31m[Deconnecte] ${reason}\x1b[0m\r\n`);
        }
        if (!conn.destroyed) this._scheduleReconnect(mod, conn);
      };

      ws.onerror = (e) => {
        console.error('[OPS:grid] WS onerror', mod, e);
      };

      ws.onmessage = (e) => {
        this._resetHeartbeat(conn);
        this._onWsData(mod, conn, e.data);
      };
    },

    _onWsData(mod, conn, data) {
      // Always accumulate in buffer cache
      let buf = this._bufferCache.get(mod) || '';
      buf += data;
      if (buf.length > MAX_BUFFER_SIZE) buf = buf.slice(-MAX_BUFFER_SIZE / 2);
      this._bufferCache.set(mod, buf);

      // Enforce max cache entries
      if (this._bufferCache.size > MAX_BUFFER_CACHE) {
        this._bufferCache.delete(this._bufferCache.keys().next().value);
      }

      // Only write to terminal if this is the active session
      if (this.activeModule !== mod || !this._term) return;

      // During buffer restore, queue live writes
      if (this._restoring) {
        this._restoreQueue.push(data);
        return;
      }

      // Backpressure: drop if queue > 128KB, schedule reconnect
      const queued = conn.pending.reduce((s, w) => s + w.length, 0);
      if (queued > BACKPRESSURE_LIMIT) {
        this._setState(mod, { _backpressure: true });
        if (!conn.dropTimer) {
          conn.dropTimer = setTimeout(() => {
            conn.dropTimer = null;
            this._setState(mod, { _backpressure: false });
            if (this._term) this._term.clear();
            if (conn.ws) { conn.ws.onclose = null; conn.ws.close(); }
            conn.attempt = 0;
            this._connectWs(mod, conn);
          }, 2000);
        }
        return;
      }

      conn.pending.push(data);
      if (!conn.frameScheduled) {
        conn.frameScheduled = true;
        requestAnimationFrame(() => this._flushPending(mod, conn));
      }
    },

    _flushPending(mod, conn) {
      conn.frameScheduled = false;
      if (!conn.pending.length || !this._term || this.activeModule !== mod) return;

      const joined = conn.pending.join('');
      conn.pending = [];

      if (joined.length <= OUTPUT_FRAME_MAX) {
        this._term.write(joined);
      } else {
        this._term.write(joined.slice(0, OUTPUT_FRAME_MAX));
        conn.pending.push(joined.slice(OUTPUT_FRAME_MAX));
        requestAnimationFrame(() => this._flushPending(mod, conn));
      }
    },

    _scheduleReconnect(mod, conn) {
      if (conn.destroyed) return;
      conn.attempt++;
      if (conn.attempt > WS_MAX_RECONNECT) {
        console.log('[OPS:grid] _scheduleReconnect — max attempts reached for', mod);
        this._setState(mod, { _reconnecting: false, _disconnected: true, _gaveUp: true });
        if (this._term && this.activeModule === mod) {
          this._term.write(`\r\n\x1b[31m[Echec] Reconnexion impossible apres ${WS_MAX_RECONNECT} tentatives.\x1b[0m\r\n`);
          this._term.write('\x1b[33mCliquer sur l\'agent dans la liste pour reessayer.\x1b[0m\r\n');
        }
        return;
      }
      const delay = Math.min(WS_RECONNECT_BASE * Math.pow(2, conn.attempt - 1), WS_RECONNECT_MAX);
      console.log('[OPS:grid] _scheduleReconnect', mod, 'attempt:', conn.attempt, 'delay:', delay);
      this._setState(mod, { _reconnecting: true, _reconnectAttempt: conn.attempt });
      const jitter = delay * (0.5 + Math.random() * 0.5);
      conn.reconnectTimer = setTimeout(() => this._connectWs(mod, conn), jitter);
    },

    _resetHeartbeat(conn) {
      clearTimeout(conn.heartbeatTimer);
      conn.heartbeatTimer = setTimeout(() => {
        if (conn.ws?.readyState === 1) conn.ws.close();
      }, WS_HEARTBEAT_MS);
    },

    _destroyConn(conn) {
      conn.destroyed = true;
      clearTimeout(conn.reconnectTimer);
      clearTimeout(conn.heartbeatTimer);
      clearTimeout(conn.dropTimer);
      if (conn.ws) { conn.ws.onclose = null; conn.ws.close(); }
    },

    _setState(mod, obj) {
      const s = this.sessions.find(s => s.name === mod);
      if (s) Object.assign(s, obj);
    },

    /* ── Grid UI actions ── */

    toggle(s) {
      const opening = !s.open;
      console.log('[OPS:grid] toggle', s.name, 'opening:', opening);
      // Accordion: close all others before opening
      if (opening) {
        for (const other of this.sessions) {
          if (other !== s) other.open = false;
        }
      }
      s.open = opening;
      if (opening) {
        this.$nextTick(() => this.activateSession(s.name));
      } else {
        this.deactivateSession(s.name);
      }
    },

    expandAll() {
      // Accordion: open only the first session
      for (const s of this.sessions) s.open = false;
      if (this.sessions.length > 0) {
        this.sessions[0].open = true;
        this.$nextTick(() => this.activateSession(this.sessions[0].name));
      }
    },

    collapseAll() {
      for (const s of this.sessions) s.open = false;
      this.activeModule = null;
    },

    pingAll() {
      for (const conn of this._connections.values()) {
        if (conn.ws?.readyState === 1) conn.ws.send('Ping\r');
      }
    },

    async refresh() {
      try {
        const res = await fetch('/api/tmux');
        if (!res.ok) { this.loading = false; return; }
        const data = await res.json();
        const list = Array.isArray(data) ? data : (data.sessions || []);
        console.log('[OPS:grid] refresh() — got', list.length, 'sessions:', list.map(s => s.name).join(', '));
        const newNames = new Set(list.map(s => s.name));
        const oldMap = new Map(this.sessions.map(s => [s.name, s]));

        // Update existing sessions' metadata
        for (const s of list) {
          const old = oldMap.get(s.name);
          if (old) { old.dead = s.dead; old.activity = s.activity; old.status = s.status; }
        }

        // Clean removed sessions
        const oldNames = new Set(oldMap.keys());
        for (const name of oldNames) {
          if (!newNames.has(name)) {
            const conn = this._connections.get(name);
            if (conn) { this._destroyConn(conn); this._connections.delete(name); }
            this._bufferCache.delete(name);
            if (this.activeModule === name) this.activeModule = null;
          }
        }

        // Add new sessions
        const added = list.filter(s => !oldNames.has(s.name));
        for (const s of added) s.open = false;

        const kept = this.sessions.filter(s => newNames.has(s.name));
        if (added.length || kept.length !== this.sessions.length) {
          this.sessions = [...kept, ...added];
        }
      } catch (err) {
        console.error('[OPS:grid] refresh() error:', err);
      }
      this.loading = false;
    }
  }));

  /* ══════════════════════════════════════════════════════════════════
   * opsTerminal — standalone terminal for detail view (get_agent).
   * Single instance per page, owns its own xterm + WS.
   * ══════════════════════════════════════════════════════════════════ */
  Alpine.data('opsTerminal', () => ({
    term: null,
    ws: null,
    connected: false,
    _module: null,
    _wsUrl: null,
    _reconnectAttempt: 0,
    _reconnectTimer: null,
    _heartbeatTimer: null,
    _dropRecoveryTimer: null,
    _inputFlushTimer: null,
    _resizeTimer: null,
    _pendingWrites: [],
    _writeFrameScheduled: false,
    _destroyed: false,
    _wasConnected: false,
    _themeObs: null,
    _inputBuffer: '',
    _resizeObserver: null,

    connect(modArg) {
      const mod = modArg || this.$el.getAttribute('data-module')
        || this.$refs.terminal?.getAttribute('data-module');
      console.log('[OPS:detail] connect()', mod, '— already connected:', !!this._module);
      if (!mod || this._module) return;
      this._module = mod;
      const el = this.$refs.terminal;
      console.log('[OPS:detail] connect() — x-ref terminal el:', el ? `${el.tagName}.${el.className} ${el.offsetWidth}x${el.offsetHeight}` : 'NOT FOUND');
      if (!el) return;

      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      this._wsUrl = `${proto}://${location.host}/ws/tmux/${mod}`;
      console.log('[OPS:detail] connect() — wsUrl:', this._wsUrl);

      // Theme observer
      this._themeObs = new MutationObserver(() => {
        if (this.term) this.term.options.theme = xtermTheme();
      });
      this._themeObs.observe(document.documentElement, {
        attributes: true, attributeFilter: ['data-theme']
      });

      this._initTerminal(el);
    },

    switchTo(mod) {
      if (!mod || mod === this._module) return;
      console.log('[OPS:detail] switchTo()', mod, '— from:', this._module);

      // Close current WS
      clearTimeout(this._reconnectTimer);
      clearTimeout(this._heartbeatTimer);
      clearTimeout(this._dropRecoveryTimer);
      if (this.ws) { this.ws.onclose = null; this.ws.close(); }
      this.ws = null;
      this.connected = false;
      this._reconnectAttempt = 0;
      this._pendingWrites = [];
      this._writeFrameScheduled = false;
      this._wasConnected = false;
      this._inputBuffer = '';

      // Update module + reconnect
      this._module = mod;
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      this._wsUrl = `${proto}://${location.host}/ws/tmux/${mod}`;

      if (this.term) {
        this.term.clear();
        this.term.reset();
        this._connectWs();
      } else {
        // Terminal not yet initialized — connect() will handle it
        this._module = null;
        this.connect(mod);
      }
    },

    destroy() {
      console.log('[OPS:detail] destroy()');
      this._destroyed = true;
      clearTimeout(this._reconnectTimer);
      clearTimeout(this._heartbeatTimer);
      clearTimeout(this._dropRecoveryTimer);
      clearTimeout(this._inputFlushTimer);
      clearTimeout(this._resizeTimer);
      this._resizeObserver?.disconnect();
      this._themeObs?.disconnect();
      if (this.ws) { this.ws.onclose = null; this.ws.close(); }
      if (this.term) this.term.dispose();
    },

    /* ── Terminal setup ── */

    _initTerminal(el) {
      console.log('[OPS:detail] _initTerminal() — loading xterm libs');
      _loadXtermLibs().then(() => {
        console.log('[OPS:detail] xterm libs loaded. Terminal class:', typeof Terminal, 'FitAddon:', typeof FitAddon);
        this.term = new Terminal({
          cursorBlink: true,
          fontSize: 14,
          lineHeight: 1.2,
          scrollback: 10000,
          fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Monaco, Consolas, monospace',
          allowProposedApi: true,
          unicode: { activeVersion: '11' },
          theme: xtermTheme()
        });
        console.log('[OPS:detail] Terminal instance created:', !!this.term);

        this.fitAddon = new FitAddon.FitAddon();
        this.term.loadAddon(this.fitAddon);
        if (window.Unicode11Addon) {
          this.term.loadAddon(new Unicode11Addon.Unicode11Addon());
          this.term.unicode.activeVersion = '11';
        }
        if (window.WebLinksAddon) {
          this.term.loadAddon(new WebLinksAddon.WebLinksAddon());
        }
        console.log('[OPS:detail] opening terminal in el:', el.offsetWidth, 'x', el.offsetHeight);
        this.term.open(el);
        console.log('[OPS:detail] term.open() done. term.element:', !!this.term.element, 'offsetHeight:', this.term.element?.offsetHeight);

        // WebGL addon after open()
        if (window.WebglAddon) {
          try {
            const webgl = new WebglAddon.WebglAddon();
            webgl.onContextLoss(() => { try { webgl.dispose(); } catch {} });
            this.term.loadAddon(webgl);
            console.log('[OPS:detail] WebGL addon loaded');
          } catch (e) {
            console.warn('[OPS:detail] WebGL addon failed', e);
          }
        }

        requestAnimationFrame(() => {
          console.log('[OPS:detail] rAF — fitting. Container:', el.offsetWidth, 'x', el.offsetHeight);
          this.fitAddon.fit();
          console.log('[OPS:detail] rAF — fit done. Terminal:', this.term.cols, 'x', this.term.rows);
          this._connectWs();
        });

        // ResizeObserver with scrollback cleanup
        this._resizeObserver = new ResizeObserver(() => {
          clearTimeout(this._resizeTimer);
          this._resizeTimer = setTimeout(() => {
            if (!this._destroyed && this.fitAddon) {
              this.fitAddon.fit();
              this.term.write('\x1b[3J');  // clean scrollback artifacts
            }
          }, RESIZE_DEBOUNCE);
        });
        this._resizeObserver.observe(el);

        // Forward resize to server
        this.term.onResize(({ cols, rows }) => {
          console.log('[OPS:detail] term.onResize', cols, 'x', rows);
          if (this.ws?.readyState === 1) {
            this.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
          }
        });

        // Input → WS with coalescing
        this.term.onData((data) => {
          if (this.ws?.readyState !== 1) return;
          this._inputBuffer += data;
          clearTimeout(this._inputFlushTimer);
          this._inputFlushTimer = setTimeout(() => {
            if (this._inputBuffer && this.ws?.readyState === 1) {
              this.ws.send(this._inputBuffer);
              this._inputBuffer = '';
            }
          }, 0);
        });
      }).catch(err => {
        console.error('[OPS:detail] xterm libs FAILED to load', err);
      });
    },

    /* ── WebSocket with reconnection ── */

    _connectWs() {
      if (this._destroyed) return;
      console.log('[OPS:detail] _connectWs() url:', this._wsUrl);
      const ws = new WebSocket(this._wsUrl);
      this.ws = ws;

      ws.onopen = () => {
        console.log('[OPS:detail] WS onopen');
        this.connected = true;
        this._reconnectAttempt = 0;
        this._resetHeartbeat();

        // Send initial dimensions
        console.log('[OPS:detail] WS onopen — sending initial resize:', this.term.cols, 'x', this.term.rows);
        ws.send(JSON.stringify({ type: 'resize', cols: this.term.cols, rows: this.term.rows }));

        // On reconnect: clear + force tmux repaint
        if (this._wasConnected) {
          this.term.clear();
          const { cols, rows } = this.term;
          setTimeout(() => {
            if (ws.readyState !== 1) return;
            ws.send(JSON.stringify({ type: 'resize', cols: cols + 1, rows }));
            ws.send(JSON.stringify({ type: 'resize', cols, rows }));
          }, 100);
        }
        this._wasConnected = true;
      };

      ws.onclose = (e) => {
        console.log('[OPS:detail] WS onclose code:', e.code, 'reason:', e.reason);
        this.connected = false;
        clearTimeout(this._heartbeatTimer);
        // Show error in terminal
        if (this.term) {
          const reason = e.reason || (e.code === 1006 ? 'connexion perdue' : '');
          this.term.write(`\r\n\x1b[31m[Deconnecte] ${reason}\x1b[0m\r\n`);
        }
        this._scheduleReconnect();
      };

      ws.onerror = (e) => {
        console.error('[OPS:detail] WS onerror', e);
      };

      ws.onmessage = (e) => {
        this._resetHeartbeat();

        // Client-side backpressure
        const queued = this._pendingWrites.reduce((s, w) => s + w.length, 0);
        if (queued > BACKPRESSURE_LIMIT) {
          if (!this._dropRecoveryTimer) {
            this._dropRecoveryTimer = setTimeout(() => {
              this._dropRecoveryTimer = null;
              this.term.clear();
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

      if (joined.length <= OUTPUT_FRAME_MAX) {
        this.term.write(joined);
      } else {
        this.term.write(joined.slice(0, OUTPUT_FRAME_MAX));
        this._pendingWrites.push(joined.slice(OUTPUT_FRAME_MAX));
        requestAnimationFrame(() => this._flushPendingWrites());
      }
    },

    _scheduleReconnect() {
      if (this._destroyed) return;
      this._reconnectAttempt++;
      if (this._reconnectAttempt > WS_MAX_RECONNECT) {
        console.log('[OPS:detail] _scheduleReconnect — max attempts reached');
        if (this.term) {
          this.term.write(`\r\n\x1b[31m[Echec] Reconnexion impossible apres ${WS_MAX_RECONNECT} tentatives.\x1b[0m\r\n`);
          this.term.write('\x1b[33mRecharger la page pour reessayer.\x1b[0m\r\n');
        }
        return;
      }
      const delay = Math.min(WS_RECONNECT_BASE * Math.pow(2, this._reconnectAttempt - 1), WS_RECONNECT_MAX);
      const jitter = delay * (0.5 + Math.random() * 0.5);
      console.log('[OPS:detail] _scheduleReconnect attempt:', this._reconnectAttempt, 'delay:', delay);
      this._reconnectTimer = setTimeout(() => this._connectWs(), jitter);
    },

    _reconnectNow() {
      this.connected = false;
      if (this.ws) { this.ws.onclose = null; this.ws.close(); }
      this._connectWs();
    },

    _resetHeartbeat() {
      clearTimeout(this._heartbeatTimer);
      this._heartbeatTimer = setTimeout(() => {
        if (this.ws?.readyState === 1) this.ws.close();
      }, WS_HEARTBEAT_MS);
    }
  }));
});

/* ── Shared xterm.js lib loader ── */
function _loadXtermLibs() {
  if (!window._xtermLoading) {
    console.log('[OPS] _loadXtermLibs() — starting CDN load');
    window._xtermLoading = Promise.all([
      loadCSS('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/css/xterm.min.css'),
      loadScript('https://cdn.jsdelivr.net/npm/@xterm/xterm@5/lib/xterm.min.js')
    ]).then(() => {
      console.log('[OPS] xterm core loaded. Loading addons...');
      return Promise.all([
        loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0/lib/addon-fit.min.js'),
        loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-unicode11@0/lib/addon-unicode11.min.js').catch(() => {}),
        loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-webgl@0/lib/addon-webgl.min.js').catch(() => {}),
        loadScript('https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0/lib/addon-web-links.min.js').catch(() => {}),
      ]);
    }).then(() => {
      console.log('[OPS] all xterm addons loaded. Globals — Terminal:', typeof Terminal, 'FitAddon:', typeof FitAddon);
    });
  }
  return window._xtermLoading;
}

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
