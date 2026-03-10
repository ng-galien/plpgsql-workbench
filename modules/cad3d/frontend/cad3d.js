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
  Alpine.data('cadViewer', function() {
    return {
      drawingId: null,
      pieces: [],
      selections: [],
      wireframe: false,
      scene: null,
      camera: null,
      renderer: null,
      controls: null,
      raycaster: null,
      mouse: null,
      _lastMouseDown: null,
      _cameraSet: false,
      hud: 'Chargement...',
      info: null,

      load: function(id) {
        this.drawingId = id;
        this._lastMouseDown = { x: 0, y: 0 };
        var self = this;
        var container = this.$refs.viewport;
        if (!container) return;

        // Lazy-load Three.js (UMD r160)
        if (typeof THREE === 'undefined') {
          var s = document.createElement('script');
          s.src = 'https://cdn.jsdelivr.net/npm/three@0.160/build/three.min.js';
          s.onload = function() {
            var s2 = document.createElement('script');
            s2.src = 'https://cdn.jsdelivr.net/npm/three@0.160/examples/js/controls/OrbitControls.js';
            s2.onload = function() { self._init3d(container); self._loadScene(); };
            document.head.appendChild(s2);
          };
          document.head.appendChild(s);
        } else {
          this._init3d(container);
          this._loadScene();
        }
      },

      _init3d: function(container) {
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x1a1a2e);

        var w = container.clientWidth;
        var h = container.clientHeight;
        this.camera = new THREE.PerspectiveCamera(50, w / h, 1, 100000);
        this.renderer = new THREE.WebGLRenderer({ antialias: true });
        this.renderer.setSize(w, h);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(this.renderer.domElement);

        // Controls
        this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
        this.controls.enableDamping = true;
        this.controls.dampingFactor = 0.08;

        // Lights
        this.scene.add(new THREE.AmbientLight(0xffffff, 0.5));
        var dl1 = new THREE.DirectionalLight(0xffffff, 0.8);
        dl1.position.set(3000, 5000, 4000);
        this.scene.add(dl1);
        var dl2 = new THREE.DirectionalLight(0xffffff, 0.3);
        dl2.position.set(-2000, -3000, 1000);
        this.scene.add(dl2);

        // Grid + axes
        this.scene.add(new THREE.GridHelper(6000, 60, 0x444466, 0x2a2a44));
        this.scene.add(new THREE.AxesHelper(500));

        // Raycaster
        this.raycaster = new THREE.Raycaster();
        this.mouse = new THREE.Vector2();

        // Events
        var self = this;
        var renderer = this.renderer;
        var camera = this.camera;
        var scene = this.scene;
        var ctrl = this.controls;
        var canvas = renderer.domElement;

        canvas.addEventListener('mousedown', function(e) {
          self._lastMouseDown.x = e.clientX;
          self._lastMouseDown.y = e.clientY;
        });

        canvas.addEventListener('mouseup', function(e) {
          var dx = e.clientX - self._lastMouseDown.x;
          var dy = e.clientY - self._lastMouseDown.y;
          if (dx * dx + dy * dy > 25) return; // drag, not click

          var rect = canvas.getBoundingClientRect();
          self.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          self.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          self.raycaster.setFromCamera(self.mouse, camera);

          var meshes = scene.children.filter(function(c) { return c.userData && c.userData.piece; });
          var hits = self.raycaster.intersectObjects(meshes);

          if (hits.length > 0) {
            var mesh = hits[0].object;
            if (e.shiftKey) {
              var idx = self.selections.indexOf(mesh);
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
          self.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          self.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          self.raycaster.setFromCamera(self.mouse, camera);
          var meshes = scene.children.filter(function(c) { return c.userData && c.userData.piece; });
          var hits = self.raycaster.intersectObjects(meshes);
          canvas.style.cursor = hits.length > 0 ? 'pointer' : 'default';
        });

        // Animate
        function animate() {
          requestAnimationFrame(animate);
          ctrl.update();
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
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify({ p_drawing_id: this.drawingId })
        })
        .then(function(r) { return r.json(); })
        .then(function(pieces) {
          if (!Array.isArray(pieces)) pieces = pieces.pieces || [];
          self.pieces = pieces;
          self._buildMeshes(pieces);
          self._updateHud(pieces);
        })
        .catch(function(e) { self.hud = 'Erreur: ' + e.message; });
      },

      _buildMeshes: function(pieces) {
        var self = this;
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
          self.scene.add(mesh);
          allVerts.push.apply(allVerts, verts);
        });

        // Auto-center camera on first load
        if (allVerts.length > 0 && !this._cameraSet) {
          var box = new THREE.Box3();
          for (var i = 0; i < allVerts.length; i += 3) {
            box.expandByPoint(new THREE.Vector3(allVerts[i], allVerts[i+1], allVerts[i+2]));
          }
          var center = box.getCenter(new THREE.Vector3());
          var size = box.getSize(new THREE.Vector3()).length();
          this.controls.target.copy(center);
          this.camera.position.copy(center.clone().add(new THREE.Vector3(size * 0.8, size * 0.6, size * 0.8)));
          this.camera.lookAt(center);
          this.controls.update();
          this._cameraSet = true;
        }
      },

      _addSelection: function(mesh) {
        if (this.selections.indexOf(mesh) >= 0) return;
        mesh._origColor = mesh.material.color.getHex();
        mesh.material.color.setHex(HIGHLIGHT);
        mesh.material.emissive = new THREE.Color(0x223344);
        this.selections.push(mesh);
      },

      _removeSelection: function(idx) {
        var m = this.selections[idx];
        m.material.color.setHex(m._origColor);
        m.material.emissive = new THREE.Color(0x000000);
        this.selections.splice(idx, 1);
        this._updateInfo();
      },

      _clearSelections: function() {
        this.selections.forEach(function(m) {
          m.material.color.setHex(m._origColor);
          m.material.emissive = new THREE.Color(0x000000);
        });
        this.selections = [];
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
        if (this.selections.length === 0) { this.info = null; return; }
        var items = [];
        var max = Math.min(this.selections.length, 4);
        for (var i = 0; i < max; i++) {
          var d = this.selections[i].userData;
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
          extra: this.selections.length > max ? (this.selections.length - max) : 0
        };
      },

      resetCamera: function() {
        this._cameraSet = false;
        // Re-center from current meshes
        var allVerts = [];
        this.scene.children.forEach(function(c) {
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
          var box = new THREE.Box3();
          for (var i = 0; i < allVerts.length; i += 3) {
            box.expandByPoint(new THREE.Vector3(allVerts[i], allVerts[i+1], allVerts[i+2]));
          }
          var center = box.getCenter(new THREE.Vector3());
          var size = box.getSize(new THREE.Vector3()).length();
          this.controls.target.copy(center);
          this.camera.position.copy(center.clone().add(new THREE.Vector3(size * 0.8, size * 0.6, size * 0.8)));
          this.camera.lookAt(center);
          this.controls.update();
          this._cameraSet = true;
        }
      },

      toggleWireframe: function() {
        this.wireframe = !this.wireframe;
        var wf = this.wireframe;
        this.scene.traverse(function(obj) {
          if (obj.isMesh && obj.material) obj.material.wireframe = wf;
        });
      },

      copyContext: function() {
        var ctx = this.selections.map(function(s) {
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
