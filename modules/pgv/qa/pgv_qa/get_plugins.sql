CREATE OR REPLACE FUNCTION pgv_qa.get_plugins()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.grid(
    -- Test 1: Plugin with priv scope + mount/unmount lifecycle
    pgv.card('Counter (priv scope)', 
      '<div x-data="testCounter">'
      || '<p>Count: <strong x-text="count"></strong></p>'
      || '<p>Priv: <strong x-text="privInfo"></strong></p>'
      || '<button @click="increment()">+</button> '
      || '<button @click="decrement()">-</button>'
      || '</div>'
      || '<script>'
      || 'pgv.plugin("testCounter", {'
      || '  data: function() { return { count: 0, privInfo: "" }; },'
      || '  priv: function() { return { secret: 42 }; },'
      || '  mount: function(el) {'
      || '    this.privInfo = "secret=" + this._priv.secret;'
      || '    el.setAttribute("data-mounted", "true");'
      || '    console.log("[testCounter] mounted");'
      || '  },'
      || '  unmount: function() {'
      || '    console.log("[testCounter] unmounted");'
      || '  },'
      || '  methods: {'
      || '    increment: function() { this.count++; this._priv.secret++; this.privInfo = "secret=" + this._priv.secret; },'
      || '    decrement: function() { this.count--; this._priv.secret--; this.privInfo = "secret=" + this._priv.secret; }'
      || '  }'
      || '});'
      || '</script>'),
    -- Test 2: Plugin with events (emit + listen)
    pgv.card('Events (emit/listen)',
      '<div x-data="testEmitter">'
      || '<button @click="send()">Emit</button>'
      || ' <span>Sent: <strong x-text="sentCount"></strong></span>'
      || '</div>'
      || '<hr>'
      || '<div x-data="testListener">'
      || '<span>Received: <strong x-text="received"></strong></span>'
      || '</div>'
      || '<script>'
      || 'pgv.plugin("testEmitter", {'
      || '  data: function() { return { sentCount: 0 }; },'
      || '  methods: {'
      || '    send: function() { this.sentCount++; this.$emit("test:ping", { n: this.sentCount }); }'
      || '  }'
      || '});'
      || 'pgv.plugin("testListener", {'
      || '  data: function() { return { received: 0 }; },'
      || '  events: { listen: { "test:ping": "onPing" } },'
      || '  methods: {'
      || '    onPing: function(detail) { this.received = detail.n; }'
      || '  }'
      || '});'
      || '</script>')
  )
  || pgv.grid(
    -- Test 3: Deps loading (already loaded dep = skip)
    pgv.card('Deps (cached)',
      '<div x-data="testDeps">'
      || '<p>Status: <strong x-text="status"></strong></p>'
      || '</div>'
      || '<script>'
      || 'pgv.plugin("testDeps", {'
      || '  deps: [{ type: "script", src: "https://cdn.jsdelivr.net/npm/marked/marked.min.js", test: function() { return typeof marked !== "undefined"; } }],'
      || '  data: function() { return { status: "loading..." }; },'
      || '  mount: function() { this.status = typeof marked !== "undefined" ? "marked loaded (cached)" : "not loaded"; }'
      || '});'
      || '</script>'),
    -- Test 4: Fallback UI (dep load failure)
    pgv.card('Fallback (bad dep)',
      '<div x-data="testBadDep">'
      || '<p>Should show error fallback below:</p>'
      || '</div>'
      || '<script>'
      || 'pgv.plugin("testBadDep", {'
      || '  deps: [{ type: "script", src: "/does-not-exist-404.js" }],'
      || '  data: function() { return { ok: false }; },'
      || '  mount: function() { this.ok = true; }'
      || '});'
      || '</script>')
  );
END;
$function$;
