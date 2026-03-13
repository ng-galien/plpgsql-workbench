# PLUGINS.md — Systeme de plugins frontend pgView

> Architecture d'integration des composants complexes (3D, terminal, charts, etc.) dans le shell Alpine.js.
> Ce document analyse les irritants actuels et propose un systeme de plugins propre, maintenable et scalable.

## Etat des lieux

### Ce qui marche bien avec Alpine.js

| Avantage | Detail |
|----------|--------|
| **Zero build** | Pas de webpack, pas de npm, pas de transpilation. Un fichier HTML + CDN. |
| **SSR natif** | PL/pgSQL genere du HTML, Alpine ajoute la reactivite. Pas de hydration. |
| **Legeret** | 16 KB. Le shell complet fait ~930 lignes (HTML + JS). |
| **Data-* contract** | Le serveur parle au client via des attributs HTML (`data-rpc`, `data-toast`, `data-redirect`). Pas de JSON API complexe. |
| **Declaratif** | `x-data`, `x-show`, `x-for` lisibles directement dans le HTML genere par SQL. |
| **Pas de state global** | Chaque page est un fetch HTML. Le "state" c'est la DB. |

### Les irritants techniques

#### 1. Pas de lifecycle — fuite memoire garantie

Quand l'utilisateur navigue, le shell fait `app.innerHTML = html`. L'ancien DOM est detruit, mais :
- Le `requestAnimationFrame` du viewer 3D tourne toujours
- Le WebSocket du terminal reste ouvert
- Le `ResizeObserver` continue d'observer un element detache
- Les event listeners sur `window` ne sont jamais retires

**Aujourd'hui** : chaque composant a un `destroy()` mais **personne ne l'appelle**. Le shell ne sait pas quels composants sont actifs.

#### 2. Proxy Alpine casse les objets complexes

Alpine wrape tout `this.*` dans un Proxy ES6. Les objets Three.js ont des proprietes `non-configurable` (`modelViewMatrix`, etc.) qui cassent silencieusement sous Proxy.

**Workaround actuel** (cad.js) : stocker les objets Three.js dans une variable closure `_gl` hors du composant Alpine :
```javascript
Alpine.data('cadViewer', function() {
  var _gl = { scene: null, camera: null, renderer: null };  // HORS Alpine
  return {
    drawingId: null,  // dans Alpine (OK, serialisable)
    load: function(id) { /* utilise _gl, pas this */ }
  };
});
```
Ca marche mais c'est fragile : chaque dev doit savoir quel objet peut aller dans `this` et lequel doit rester dans la closure. Aucune convention formalisee.

#### 3. `$el` est contextuel, pas le root

Dans un handler `@click` sur un element enfant, `$el` pointe vers l'element clique, pas vers le root du composant.

**Workaround actuel** :
```javascript
init() { this._rootEl = this.$el; }  // capturer le root
```
Chaque composant doit se souvenir de faire ca. Pas de garde-fou.

#### 4. Chargement d'assets ad-hoc

Trois patterns differents dans le meme projet :

| Module | Pattern | Probleme |
|--------|---------|----------|
| pgv | `pgv-modules.js` avec `document.write()` | Synchrone, bloque le rendu, fragile |
| cad | `createElement('script')` dans `load()` | Pas de cache, pas de gestion d'erreur |
| ops | `Promise.all([loadScript(...)])` | Meilleur, mais isole dans ops.js |

Pas de standard pour charger une librairie externe.

#### 5. Script re-execution hack

`innerHTML` ne re-execute pas les `<script>`. Le shell les re-cree manuellement :
```javascript
el.querySelectorAll('script').forEach(function(old) {
  var s = document.createElement('script');
  s.textContent = old.textContent;
  old.parentNode.replaceChild(s, old);
});
```
C'est un hack connu qui marche, mais qui empeche toute gestion d'ordre de chargement et de gestion d'erreur.

#### 6. Pas d'isolation d'erreur

Si le viewer 3D crash (WebGL context lost, geometry invalide), ca peut casser la page entiere. Pas de try/catch autour de l'init des composants. Pas de fallback UI.

#### 7. Communication inter-composants fragile

Le viewer CAD et l'arbre de pieces communiquent via `$dispatch` sur `window` :
```javascript
// cad.js viewer
this.$dispatch('cad-select', { pieces: [...] });

// fragment_viewer.sql
'@cad-piece-select.window="selectByIds($event.detail)"'
```
Ca marche pour 2 composants. Mais :
- Pas de typage des events
- Pas de cleanup des listeners
- Collision de noms possible entre modules
- Invisible dans le code SQL (l'event est dans un string)

---

## Proposition : pgv.plugin

### Principe

Un **registre de plugins** dans le shell qui standardise :
1. **Declaration** — un plugin declare ses deps, son composant Alpine, ses hooks lifecycle
2. **Chargement** — les deps (CDN/local) sont chargees une seule fois, avec cache et fallback
3. **Montage** — le shell monte automatiquement les plugins trouves dans le DOM apres chaque navigation
4. **Demontage** — le shell demonte automatiquement les plugins avant de remplacer le DOM
5. **Isolation** — les objets non-serialisables vivent dans un scope protege, pas dans Alpine

### API

```javascript
// ── Declaration d'un plugin (dans cad.js) ──────────────────────

pgv.plugin('cadViewer', {

  // Dependances chargees avant mount (lazy, cached)
  deps: [
    { type: 'script', src: '/three.min.js', test: function() { return typeof THREE !== 'undefined'; } }
  ],

  // Proprietes reactives Alpine (serialisables uniquement)
  data: function() {
    return {
      drawingId: null,
      wireframe: false,
      selCount: 0,
      hud: '',
      info: null
    };
  },

  // Scope non-reactif (objets complexes, hors Proxy)
  // Accessible via this._priv dans les methodes
  priv: function() {
    return {
      scene: null,
      camera: null,
      renderer: null,
      controls: null,
      animId: null,
      resizeObs: null
    };
  },

  // Appele quand le composant entre dans le DOM
  // el = element avec x-data, priv = scope non-reactif
  mount: function(el) {
    this._rootEl = el;
    // this._priv.scene, this._priv.renderer, etc. sont dispo
  },

  // Appele avant que le DOM soit remplace (navigation)
  unmount: function() {
    cancelAnimationFrame(this._priv.animId);
    this._priv.resizeObs.disconnect();
    this._priv.renderer.dispose();
    this._priv.controls.dispose();
    // Cleanup complet, zero fuite
  },

  // Methodes du composant Alpine (ont acces a this + this._priv)
  methods: {
    load: function(id) {
      this.drawingId = id;
      this._initScene();
      this._loadGeometry();
    },
    _initScene: function() {
      var p = this._priv;
      p.scene = new THREE.Scene();
      p.renderer = new THREE.WebGLRenderer({ antialias: true });
      // ...
    },
    toggleWireframe: function() {
      this.wireframe = !this.wireframe;
      // ...
    }
  },

  // Events emis/recus (documentation + cleanup auto)
  events: {
    emit: ['cad:select', 'cad:focus'],
    listen: {
      'cad:piece-select': 'selectByIds',
      'cad:piece-toggle': 'toggleById'
    }
  }
});
```

### Implementation dans le shell

```javascript
// ── pgv.plugin runtime (~120 lignes) ────────────────────────────

(function() {
  var registry = {};      // name -> definition
  var instances = [];      // { name, el, component, priv } des plugins montes

  // ── Enregistrement ──────────────────────────────────────────
  pgv.plugin = function(name, def) {
    registry[name] = def;

    // Generer le composant Alpine correspondant
    Alpine.data(name, function() {
      var self = this;
      var comp = {};

      // Donnees reactives
      if (def.data) Object.assign(comp, def.data());

      // Scope prive (hors Proxy)
      var priv = def.priv ? def.priv() : {};

      // Expose _priv en lecture (pas reactif)
      Object.defineProperty(comp, '_priv', {
        get: function() { return priv; },
        enumerable: false,
        configurable: false
      });

      // Root element capture automatique
      comp.init = function() {
        this._rootEl = this.$el;
        // Lier les event listeners declares
        if (def.events && def.events.listen) {
          this._cleanups = [];
          var self = this;
          Object.keys(def.events.listen).forEach(function(evt) {
            var method = def.events.listen[evt];
            var handler = function(e) { self[method](e.detail); };
            window.addEventListener(evt, handler);
            self._cleanups.push(function() {
              window.removeEventListener(evt, handler);
            });
          });
        }
      };

      // Methodes
      if (def.methods) {
        Object.keys(def.methods).forEach(function(k) {
          comp[k] = def.methods[k];
        });
      }

      // Emit helper
      comp.$emit = function(name, detail) {
        window.dispatchEvent(new CustomEvent(name, { detail: detail }));
      };

      return comp;
    });
  };

  // ── Montage (appele par _enhance) ───────────────────────────
  pgv.mount = function(el) {
    el.querySelectorAll('[x-data]').forEach(function(node) {
      var name = node.getAttribute('x-data').replace(/\(.*/, '').trim();
      var def = registry[name];
      if (!def) return;  // composant Alpine natif, pas un plugin

      // Charger les deps avant mount
      var depsReady = !def.deps ? Promise.resolve() : loadDeps(def.deps);
      depsReady.then(function() {
        // Appeler mount() si defini
        // Alpine aura deja initialise le composant via initTree
        // On retrouve l'instance via Alpine.$data(node)
        var instance = Alpine.$data(node);
        if (def.mount) def.mount.call(instance, node);
        instances.push({ name: name, el: node, def: def, instance: instance });
      }).catch(function(err) {
        console.error('[pgv.plugin] ' + name + ' mount failed:', err);
        node.innerHTML = '<div class="pgv-plugin-error">'
          + '<p>Composant ' + name + ' indisponible</p>'
          + '<small>' + err.message + '</small>'
          + '</div>';
      });
    });
  };

  // ── Demontage (appele avant innerHTML) ──────────────────────
  pgv.unmount = function() {
    instances.forEach(function(inst) {
      try {
        // Cleanup event listeners
        if (inst.instance._cleanups) {
          inst.instance._cleanups.forEach(function(fn) { fn(); });
        }
        // Appeler unmount() du plugin
        if (inst.def.unmount) inst.def.unmount.call(inst.instance);
      } catch (e) {
        console.warn('[pgv.plugin] unmount error ' + inst.name + ':', e);
      }
    });
    instances = [];
  };

  // ── Chargement de deps (cache global) ───────────────────────
  var depCache = {};
  function loadDeps(deps) {
    return Promise.all(deps.map(function(dep) {
      // Deja charge ?
      if (dep.test && dep.test()) return Promise.resolve();
      // En cours de chargement ?
      if (depCache[dep.src]) return depCache[dep.src];

      depCache[dep.src] = new Promise(function(resolve, reject) {
        var el;
        if (dep.type === 'script') {
          el = document.createElement('script');
          el.src = dep.src;
        } else if (dep.type === 'style') {
          el = document.createElement('link');
          el.rel = 'stylesheet';
          el.href = dep.src;
        }
        el.onload = resolve;
        el.onerror = function() { reject(new Error('Failed to load ' + dep.src)); };
        document.head.appendChild(el);
      });
      return depCache[dep.src];
    }));
  }

  window.pgv = window.pgv || {};
})();
```

### Integration dans le shell existant

Deux lignes a modifier dans `index.html` :

```javascript
// AVANT (dans _render)
app.innerHTML = html;

// APRES
pgv.unmount();           // <-- demonte les plugins actifs
app.innerHTML = html;

// AVANT (dans _enhance)
Alpine.initTree(el);

// APRES
Alpine.initTree(el);
pgv.mount(el);           // <-- monte les nouveaux plugins
```

C'est tout. Le reste du shell ne change pas.

---

## Migration des composants existants

### cad.js — Avant / Apres

**Avant** (590 lignes, workaround closure `_gl`) :
```javascript
Alpine.data('cadViewer', function() {
  var _gl = { scene: null, camera: null, renderer: null, controls: null, animId: null };
  return {
    drawingId: null,
    wireframe: false,
    init: function() { this._rootEl = this.$el; },
    load: function(id) {
      if (typeof THREE === 'undefined') {
        var s = document.createElement('script');
        s.src = '/three.min.js';
        s.onload = function() { /* init */ };
        document.head.appendChild(s);
      }
    },
    destroy: function() {  // PERSONNE NE L'APPELLE
      cancelAnimationFrame(_gl.animId);
      _gl.renderer.dispose();
    }
  };
});
```

**Apres** (meme logique, structure claire) :
```javascript
pgv.plugin('cadViewer', {
  deps: [
    { type: 'script', src: '/three.min.js', test: function() { return typeof THREE !== 'undefined'; } }
  ],
  data: function() {
    return { drawingId: null, wireframe: false, selCount: 0, hud: '', info: null };
  },
  priv: function() {
    return { scene: null, camera: null, renderer: null, controls: null, animId: null, ro: null };
  },
  mount: function(el) {
    // THREE est garanti charge (deps resolues)
  },
  unmount: function() {
    // APPELE AUTOMATIQUEMENT par le shell
    cancelAnimationFrame(this._priv.animId);
    this._priv.ro.disconnect();
    this._priv.renderer.dispose();
    this._priv.controls.dispose();
  },
  methods: {
    load: function(id) { /* ... */ },
    toggleWireframe: function() { /* ... */ }
  },
  events: {
    emit: ['cad:select'],
    listen: { 'cad:piece-select': 'selectByIds', 'cad:piece-toggle': 'toggleById' }
  }
});
```

**Ce qui change** :
- Plus de workaround closure → `priv` standardise
- Plus de chargement manual de Three.js → `deps` automatique
- Plus de `destroy()` orphelin → `unmount()` appele par le shell
- Plus de `init() { this._rootEl = this.$el; }` → fait par le runtime
- Plus de listeners sur `window` non nettoyes → `events.listen` + cleanup auto
- Erreur de chargement → fallback UI automatique

### ops.js — Meme pattern

```javascript
pgv.plugin('opsTmuxGrid', {
  deps: [
    { type: 'style', src: 'https://cdn.jsdelivr.net/npm/@xterm/xterm@5/css/xterm.min.css' },
    { type: 'script', src: 'https://cdn.jsdelivr.net/npm/@xterm/xterm@5/lib/xterm.min.js',
      test: function() { return typeof Terminal !== 'undefined'; } },
    { type: 'script', src: 'https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0/.../addon-fit.min.js' }
  ],
  data: function() {
    return { sessions: [], activeModule: null, connected: {} };
  },
  priv: function() {
    return { term: null, fitAddon: null, connections: new Map(), bufferCache: new Map() };
  },
  unmount: function() {
    // Fermer TOUS les WebSockets
    this._priv.connections.forEach(function(conn) { conn.ws.close(); });
    this._priv.connections.clear();
    this._priv.bufferCache.clear();
    if (this._priv.term) this._priv.term.dispose();
  },
  methods: { /* ... */ }
});
```

---

## Ce que le PL/pgSQL ne change pas

Le HTML genere par les fonctions SQL reste identique :

```sql
-- cad.fragment_viewer(p_id) — pas de changement
RETURN '<div x-data="cadViewer" x-init="load(' || p_drawing_id || ')"'
  || ' class="cad-viewer">'
  || '<div x-ref="viewport" class="cad-viewport"></div>'
  || '</div>';
```

Le contrat `x-data="pluginName"` est le meme. Le shell detecte que c'est un plugin (present dans le registre) et applique le lifecycle. Les composants Alpine natifs (tabs, dialogs) continuent de fonctionner sans changement.

---

## pgv-modules.js — remplacement

### Avant (document.write, synchrone, fragile)

```javascript
// Auto-generated — DO NOT EDIT
document.write('<link rel="stylesheet" href="/cad.css">');
document.write('<script src="/three.min.js"><\/script>');
document.write('<script src="/cad.js"><\/script>');
document.write('<script src="/ops.js"><\/script>');
```

### Apres (declaratif, lazy)

```javascript
// Auto-generated — DO NOT EDIT
// Seuls les fichiers plugin sont charges au boot (pas les deps lourdes)
(function() {
  var modules = [
    { styles: ['/cad.css'], scripts: ['/cad.js'] },
    { styles: ['/ops.css'], scripts: ['/ops.js'] }
  ];
  modules.forEach(function(mod) {
    mod.styles.forEach(function(href) {
      var l = document.createElement('link');
      l.rel = 'stylesheet'; l.href = href;
      document.head.appendChild(l);
    });
    mod.scripts.forEach(function(src) {
      var s = document.createElement('script');
      s.src = src; s.defer = true;
      document.head.appendChild(s);
    });
  });
})();
```

**Les deps lourdes (three.min.js, xterm.js) ne sont plus chargees au boot.** Elles sont declarees dans le plugin et chargees a la demande, uniquement quand la page les utilise.

---

## Avantages du systeme plugin

| Avant | Apres |
|-------|-------|
| Memory leaks sur navigation | `unmount()` automatique |
| Workaround closure `_gl` | `priv` standardise, hors Proxy |
| `this._rootEl = this.$el` manuel | Fait par le runtime |
| Chargement deps ad-hoc | `deps` declaratif avec cache et test |
| `document.write()` bloquant | Chargement defer, deps lazy |
| Crash composant = crash page | try/catch + fallback UI |
| Event listeners orphelins | `events.listen` + cleanup auto |
| Pas de visibilite sur les composants montes | `pgv.instances` inspectable |
| Chaque module invente son pattern | Convention unique |

---

## Composants futurs facilites

Avec le systeme plugin, integrer un nouveau composant complexe suit toujours le meme pattern :

### Exemple : chart (Chart.js)

```javascript
pgv.plugin('pgvChart', {
  deps: [
    { type: 'script', src: 'https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js',
      test: function() { return typeof Chart !== 'undefined'; } }
  ],
  data: function() { return { type: 'bar', title: '' }; },
  priv: function() { return { chart: null }; },
  mount: function(el) {},
  unmount: function() {
    if (this._priv.chart) this._priv.chart.destroy();
  },
  methods: {
    render: function(config) {
      var canvas = this._rootEl.querySelector('canvas');
      this._priv.chart = new Chart(canvas, config);
    }
  }
});
```

```sql
-- PL/pgSQL
RETURN '<div x-data="pgvChart" x-init="render(' || v_chart_config::text || ')">'
  || '<canvas></canvas>'
  || '</div>';
```

### Exemple : editeur de code (CodeMirror)

```javascript
pgv.plugin('codeEditor', {
  deps: [
    { type: 'script', src: 'https://cdn.jsdelivr.net/npm/codemirror@6/...',
      test: function() { return typeof EditorView !== 'undefined'; } }
  ],
  priv: function() { return { view: null }; },
  unmount: function() { if (this._priv.view) this._priv.view.destroy(); },
  methods: {
    init: function(lang, value) { /* ... */ }
  }
});
```

### Exemple : carte (Leaflet)

```javascript
pgv.plugin('pgvMap', {
  deps: [
    { type: 'style', src: 'https://unpkg.com/leaflet@1/dist/leaflet.css' },
    { type: 'script', src: 'https://unpkg.com/leaflet@1/dist/leaflet.js',
      test: function() { return typeof L !== 'undefined'; } }
  ],
  priv: function() { return { map: null }; },
  unmount: function() { if (this._priv.map) this._priv.map.remove(); },
  methods: {
    show: function(lat, lng, zoom) {
      this._priv.map = L.map(this._rootEl.querySelector('.map-container'))
        .setView([lat, lng], zoom);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(this._priv.map);
    }
  }
});
```

Meme structure, meme lifecycle, meme garantie de cleanup. Un dev qui connait un plugin sait ecrire les autres.

---

## Plan d'implementation

### Phase 1 — Runtime plugin (~120 lignes JS)

1. Ecrire `pgv.plugin()`, `pgv.mount()`, `pgv.unmount()`, `loadDeps()` dans le shell
2. Ajouter `pgv.unmount()` avant `innerHTML` dans `_render()`
3. Ajouter `pgv.mount(el)` apres `Alpine.initTree(el)` dans `_enhance()`
4. Tester avec un plugin minimal (ex: `pgvChart`)

### Phase 2 — Migration cad.js

1. Convertir `cadViewer` en `pgv.plugin('cadViewer', { ... })`
2. Convertir `cadPieceTree` en plugin
3. Supprimer le chargement Three.js de `pgv-modules.js`
4. Verifier : navigation cad -> crm -> cad (cleanup + re-init)

### Phase 3 — Migration ops.js

1. Convertir `opsTmuxGrid` et `opsTerminal` en plugins
2. Supprimer le chargement xterm de `pgv-modules.js`
3. Verifier : navigation ops -> crm -> ops (WebSocket cleanup)

### Phase 4 — pgv-modules.js v2

1. Generer le nouveau format (defer, sans deps lourdes)
2. Mettre a jour le Makefile `dev-sync`
3. Supprimer `document.write()`

---

## Ce qui ne change pas

- **Alpine.js reste le framework reactif** — le plugin system est une couche au-dessus, pas un remplacement
- **PicoCSS reste le framework CSS** — pgview.css + modules CSS
- **Le data-\* contract reste** — `data-rpc`, `data-toast`, `data-redirect`, `data-confirm`
- **Le HTML est genere par PL/pgSQL** — les fonctions SQL ne changent pas
- **Les composants Alpine simples** (tabs, dialogs, select-search) restent tels quels — seuls les composants avec des deps lourdes ou du lifecycle complexe deviennent des plugins
- **`pgv.mount()` est idempotent** — appeler deux fois sur le meme DOM ne re-monte pas
