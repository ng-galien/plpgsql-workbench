/**
 * cad3d — Alpine.js components for CAD module
 *
 * Registers Alpine components that can be used in PL/pgSQL fragments:
 *   <div x-data="cadViewer" x-init="load(drawingId)">
 *   <div x-data="cadTree">
 */

(function() {
  function register() {

  var COLORS = {
    poteau: 0xc8956c, traverse: 0xa07850, chevron: 0xd4a76a,
    lisse: 0xb8925a, montant: 0xc8956c, default: 0xc8a882
  };
  var HIGHLIGHT = 0x66aaff;

  // --- 3D Viewer component ---
  // Three.js objects stored outside Alpine reactivity to avoid Proxy conflicts.
  // Alpine wraps this.* in Proxies; Three.js objects have non-configurable
  // properties (modelViewMatrix, etc.) that break under Proxy.
  Alpine.data('cadViewer', function() {
    var _gl = { scene: null, camera: null, renderer: null, controls: null,
      raycaster: null, mouse: null, lastMouse: { x: 0, y: 0 },
      cameraSet: false, selections: [] };
    window._gl = _gl; // DEBUG

    return {
      drawingId: null,
      wireframe: false,
      selCount: 0,
      hud: 'Chargement...',
      info: null,

      load: function(id) {
        this.drawingId = id;
        var self = this;
        var container = this.$refs.viewport;
        if (!container) return;

        // Lazy-load Three.js + OrbitControls (UMD bundle r183)
        if (typeof THREE === 'undefined') {
          var s = document.createElement('script');
          s.src = 'https://cdn.jsdelivr.net/gh/paulmasson/threejs-with-controls@r183/build/three.min.js';
          s.onload = function() { self._init3d(container); self._loadScene(); };
          document.head.appendChild(s);
        } else {
          this._init3d(container);
          this._loadScene();
        }
      },

      _init3d: function(container) {
        var scene = new THREE.Scene();
        scene.background = new THREE.Color(0x1a1a2e);
        _gl.scene = scene;

        var w = container.clientWidth;
        var h = container.clientHeight;
        var camera = new THREE.PerspectiveCamera(50, w / h, 1, 100000);
        _gl.camera = camera;

        var renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(w, h);
        renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(renderer.domElement);
        _gl.renderer = renderer;

        // Controls
        var controls = new THREE.OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.08;
        _gl.controls = controls;

        // Lights
        scene.add(new THREE.AmbientLight(0xffffff, 0.5));
        var dl1 = new THREE.DirectionalLight(0xffffff, 0.8);
        dl1.position.set(3000, 5000, 4000);
        scene.add(dl1);
        var dl2 = new THREE.DirectionalLight(0xffffff, 0.3);
        dl2.position.set(-2000, -3000, 1000);
        scene.add(dl2);

        // Grid + axes
        scene.add(new THREE.GridHelper(6000, 60, 0x444466, 0x2a2a44));
        scene.add(new THREE.AxesHelper(500));

        // Raycaster
        _gl.raycaster = new THREE.Raycaster();
        _gl.mouse = new THREE.Vector2();

        // Events
        var self = this;
        var canvas = renderer.domElement;

        canvas.addEventListener('mousedown', function(e) {
          _gl.lastMouse.x = e.clientX;
          _gl.lastMouse.y = e.clientY;
        });

        canvas.addEventListener('mouseup', function(e) {
          var dx = e.clientX - _gl.lastMouse.x;
          var dy = e.clientY - _gl.lastMouse.y;
          if (dx * dx + dy * dy > 25) return; // drag, not click

          var rect = canvas.getBoundingClientRect();
          _gl.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          _gl.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          _gl.raycaster.setFromCamera(_gl.mouse, camera);

          var meshes = scene.children.filter(function(c) { return c.userData && c.userData.piece; });
          var hits = _gl.raycaster.intersectObjects(meshes);

          if (hits.length > 0) {
            var mesh = hits[0].object;
            if (e.shiftKey) {
              var idx = _gl.selections.indexOf(mesh);
              if (idx >= 0) { self._removeSelection(idx); }
              else { self._addSelection(mesh); }
            } else {
              self._clearSelections();
              self._addSelection(mesh);
            }
            self._updateInfo();
          } else {
            self._clearSelections();
          }
        });

        canvas.addEventListener('mousemove', function(e) {
          var rect = canvas.getBoundingClientRect();
          _gl.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          _gl.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          _gl.raycaster.setFromCamera(_gl.mouse, camera);
          var meshes = scene.children.filter(function(c) { return c.userData && c.userData.piece; });
          var hits = _gl.raycaster.intersectObjects(meshes);
          canvas.style.cursor = hits.length > 0 ? 'pointer' : 'default';
        });

        // Animate
        function animate() {
          requestAnimationFrame(animate);
          controls.update();
          renderer.render(scene, camera);
        }
        animate();

        // Resize observer
        var ro = new ResizeObserver(function() {
          var w2 = container.clientWidth;
          var h2 = container.clientHeight;
          if (w2 === 0 || h2 === 0) return;
          camera.aspect = w2 / h2;
          camera.updateProjectionMatrix();
          renderer.setSize(w2, h2);
        });
        ro.observe(container);
      },

      _loadScene: function() {
        var self = this;
        fetch('/rpc/scene_json', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Content-Profile': 'cad' },
          body: JSON.stringify({ p_drawing_id: this.drawingId })
        })
        .then(function(r) { return r.json(); })
        .then(function(pieces) {
          if (!Array.isArray(pieces)) pieces = pieces.pieces || [];
          self._buildMeshes(pieces);
          self._updateHud(pieces);
        })
        .catch(function(e) { self.hud = 'Erreur: ' + e.message; });
      },

      _buildMeshes: function(pieces) {
        var scene = _gl.scene;
        var allVerts = [];

        pieces.forEach(function(p) {
          var verts = [];
          if (p.mesh && p.mesh.geometries) {
            p.mesh.geometries.forEach(function(g) {
              if (g.coordinates && g.coordinates[0]) {
                var ring = g.coordinates[0];
                if (ring.length >= 3) {
                  // GeoJSON [x,y,z] -> Three.js [x,z,-y] (Y-up)
                  verts.push(ring[0][0], ring[0][2], -ring[0][1]);
                  verts.push(ring[1][0], ring[1][2], -ring[1][1]);
                  verts.push(ring[2][0], ring[2][2], -ring[2][1]);
                }
              }
            });
          }
          if (verts.length === 0) return;

          var geom = new THREE.BufferGeometry();
          geom.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
          geom.computeVertexNormals();

          var color = COLORS[p.role] || COLORS.default;
          var mat = new THREE.MeshPhongMaterial({ color: color, flatShading: true, side: THREE.DoubleSide });
          var mesh = new THREE.Mesh(geom, mat);
          mesh.userData = { piece: true, id: p.id, label: p.label, role: p.role,
            section: p.section, length_mm: p.length_mm, wood_type: p.wood_type };
          scene.add(mesh);
          allVerts.push.apply(allVerts, verts);
        });

        // Auto-center camera on first load
        if (allVerts.length > 0 && !_gl.cameraSet) {
          this._centerCamera(allVerts);
        }
      },

      _centerCamera: function(allVerts) {
        var box = new THREE.Box3();
        for (var i = 0; i < allVerts.length; i += 3) {
          box.expandByPoint(new THREE.Vector3(allVerts[i], allVerts[i+1], allVerts[i+2]));
        }
        var center = box.getCenter(new THREE.Vector3());
        var size = box.getSize(new THREE.Vector3()).length();
        _gl.controls.target.copy(center);
        _gl.camera.position.copy(center.clone().add(new THREE.Vector3(size * 0.8, size * 0.6, size * 0.8)));
        _gl.camera.lookAt(center);
        _gl.controls.update();
        _gl.cameraSet = true;
      },

      _addSelection: function(mesh) {
        if (_gl.selections.indexOf(mesh) >= 0) return;
        mesh._origColor = mesh.material.color.getHex();
        mesh.material.color.setHex(HIGHLIGHT);
        mesh.material.emissive = new THREE.Color(0x223344);
        _gl.selections.push(mesh);
        this.selCount = _gl.selections.length;
      },

      _removeSelection: function(idx) {
        var m = _gl.selections[idx];
        m.material.color.setHex(m._origColor);
        m.material.emissive = new THREE.Color(0x000000);
        _gl.selections.splice(idx, 1);
        this.selCount = _gl.selections.length;
        this._updateInfo();
      },

      _clearSelections: function() {
        _gl.selections.forEach(function(m) {
          m.material.color.setHex(m._origColor);
          m.material.emissive = new THREE.Color(0x000000);
        });
        _gl.selections = [];
        this.selCount = 0;
        this.info = null;
      },

      _updateHud: function(pieces) {
        var total = pieces.length;
        var volume = pieces.reduce(function(sum, p) {
          var s = (p.section || '0x0').split('x');
          return sum + (parseFloat(s[0]) * parseFloat(s[1]) * (p.length_mm || 0));
        }, 0);
        this.hud = total + ' pi\u00e8ces \u2014 ' + (volume / 1e9).toFixed(4) + ' m\u00b3 bois';
      },

      _updateInfo: function() {
        if (_gl.selections.length === 0) { this.info = null; return; }
        var items = [];
        var max = Math.min(_gl.selections.length, 4);
        for (var i = 0; i < max; i++) {
          var d = _gl.selections[i].userData;
          items.push({
            role: d.role || '',
            label: d.label || 'Sans nom',
            section: d.section,
            length_mm: Math.round(d.length_mm || 0),
            wood_type: d.wood_type || '',
            id: d.id
          });
        }
        this.info = {
          items: items,
          extra: _gl.selections.length > max ? (_gl.selections.length - max) : 0
        };
      },

      resetCamera: function() {
        _gl.cameraSet = false;
        var allVerts = [];
        _gl.scene.children.forEach(function(c) {
          if (c.userData && c.userData.piece && c.geometry) {
            var pos = c.geometry.getAttribute('position');
            if (pos) {
              for (var i = 0; i < pos.count; i++) {
                allVerts.push(pos.getX(i), pos.getY(i), pos.getZ(i));
              }
            }
          }
        });
        if (allVerts.length > 0) {
          this._centerCamera(allVerts);
        }
      },

      toggleWireframe: function() {
        this.wireframe = !this.wireframe;
        var wf = this.wireframe;
        _gl.scene.traverse(function(obj) {
          if (obj.isMesh && obj.material) obj.material.wireframe = wf;
        });
      },

      copyContext: function() {
        var ctx = _gl.selections.map(function(s) {
          var d = s.userData;
          return '#' + d.id + ' ' + (d.label || '?') + ' [' + d.role + '] ' + d.section + ' ' + Math.round(d.length_mm) + 'mm ' + d.wood_type;
        }).join('\n');
        navigator.clipboard.writeText(ctx);
      }
    };
  });

  // --- Tree Explorer component ---
  Alpine.data('cadTree', function() {
    return {
      selected: null,

      init: function() {
        this.$el.querySelectorAll('.cad-tree-swatch[data-color]').forEach(function(el) {
          el.style.setProperty('--cad-swatch-color', el.dataset.color);
        });
      },

      select: function(shapeId) {
        if (this.selected) {
          var prev = document.querySelector('[data-shape-id="' + this.selected + '"]');
          if (prev) prev.classList.remove('cad-highlight');
          var prevNode = document.querySelector('.cad-tree-node[data-id="' + this.selected + '"]');
          if (prevNode) prevNode.classList.remove('cad-tree-active');
        }
        this.selected = shapeId;
        var el = document.querySelector('[data-shape-id="' + shapeId + '"]');
        if (el) el.classList.add('cad-highlight');
        var node = document.querySelector('.cad-tree-node[data-id="' + shapeId + '"]');
        if (node) node.classList.add('cad-tree-active');
      },

      selectGroup: function(groupId) {
        var g = document.querySelector('[data-group-id="' + groupId + '"]');
        if (g) {
          g.querySelectorAll('[data-shape-id]').forEach(function(el) {
            el.classList.add('cad-highlight');
          });
        }
      },

      toggleLayer: function(layerId) {
        var g = document.getElementById('layer-' + layerId);
        if (!g) return;
        var hidden = g.style.display === 'none';
        g.style.display = hidden ? '' : 'none';
        var btn = document.querySelector('.cad-tree-eye[data-layer="' + layerId + '"]');
        if (btn) btn.textContent = hidden ? '\u25C9' : '\u25CB';
      }
    };
  });

  } // end register()

  // Register now if Alpine is ready, otherwise wait for alpine:init
  if (window.Alpine) {
    register();
  } else {
    document.addEventListener('alpine:init', register);
  }
})();
