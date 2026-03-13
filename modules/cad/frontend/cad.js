/**
 * cad — pgv.plugin components for CAD module
 *
 * Plugins (lifecycle-managed by pgv runtime):
 *   cadViewer  — 3D Three.js viewer (deps: three.min.js)
 *   cadPieceTree — 3D piece tree with selection/visibility
 *
 * Alpine.data (simple, no lifecycle):
 *   cadTree — 2D shape tree explorer
 */

(function() {

  var COLORS = {
    poteau: 0xc8956c, traverse: 0xa07850, chevron: 0xd4a76a,
    lisse: 0xb8925a, montant: 0xc8956c, default: 0xc8a882
  };
  var HIGHLIGHT = 0x66aaff;

  // ── 3D Viewer plugin ────────────────────────────────────────────

  pgv.plugin('cadViewer', {

    deps: [
      { type: 'script', src: '/cad/three.min.js', test: function() { return typeof THREE !== 'undefined'; } }
    ],

    data: function() {
      return {
        drawingId: null,
        wireframe: false,
        selCount: 0,
        hud: 'Chargement...',
        info: null
      };
    },

    priv: function() {
      return {
        scene: null, camera: null, renderer: null, controls: null,
        raycaster: null, mouse: null, lastMouse: { x: 0, y: 0 },
        cameraSet: false, selections: [],
        groupMap: {}, pieceMeshes: [], animId: null, ro: null
      };
    },

    mount: function(el) {
      // THREE is guaranteed loaded (deps resolved before mount)
      // x-init="load(id)" triggers actual initialization
    },

    unmount: function() {
      var p = this._priv;
      if (p.animId) cancelAnimationFrame(p.animId);
      if (p.ro) p.ro.disconnect();
      p.pieceMeshes.forEach(function(m) {
        m.geometry.dispose();
        m.material.dispose();
      });
      if (p.controls) p.controls.dispose();
      if (p.renderer) {
        p.renderer.dispose();
        p.renderer.domElement.remove();
      }
      p.scene = null;
      p.pieceMeshes = [];
      p.selections = [];
      p.groupMap = {};
    },

    methods: {

      load: function(id) {
        this.drawingId = id;
        var container = this.$refs.viewport;
        if (!container) return;
        // THREE is guaranteed loaded by deps — init directly
        this._init3d(container);
        this._loadScene();
      },

      _init3d: function(container) {
        var p = this._priv;

        var scene = new THREE.Scene();
        scene.background = new THREE.Color(0x1a1a2e);
        p.scene = scene;

        var w = container.clientWidth;
        var h = container.clientHeight;
        var camera = new THREE.PerspectiveCamera(50, w / h, 1, 100000);
        p.camera = camera;

        var renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(w, h);
        renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(renderer.domElement);
        p.renderer = renderer;

        // Controls
        var controls = new THREE.OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.08;
        p.controls = controls;

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
        p.raycaster = new THREE.Raycaster();
        p.mouse = new THREE.Vector2();

        // Events
        var self = this;
        var canvas = renderer.domElement;

        canvas.addEventListener('mousedown', function(e) {
          p.lastMouse.x = e.clientX;
          p.lastMouse.y = e.clientY;
        });

        canvas.addEventListener('mouseup', function(e) {
          var dx = e.clientX - p.lastMouse.x;
          var dy = e.clientY - p.lastMouse.y;
          if (dx * dx + dy * dy > 25) return; // drag, not click

          var rect = canvas.getBoundingClientRect();
          p.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          p.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          p.raycaster.setFromCamera(p.mouse, camera);

          var hits = p.raycaster.intersectObjects(p.pieceMeshes);

          if (hits.length > 0) {
            var mesh = hits[0].object;
            if (e.shiftKey) {
              // Shift+click: toggle individual piece
              var idx = p.selections.indexOf(mesh);
              if (idx >= 0) { self._removeSelection(idx); }
              else { self._addSelection(mesh); }
            } else {
              self._clearSelections();
              // Click on grouped piece: select entire group
              var gid = mesh.userData.group_id;
              if (gid && p.groupMap[gid]) {
                p.groupMap[gid].forEach(function(m) { self._addSelection(m); });
              } else {
                self._addSelection(mesh);
              }
            }
            self._updateInfo();
          } else {
            self._clearSelections();
          }
        });

        // Double-click: select individual piece (override group)
        canvas.addEventListener('dblclick', function(e) {
          var rect = canvas.getBoundingClientRect();
          p.mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
          p.mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
          p.raycaster.setFromCamera(p.mouse, camera);

          var hits = p.raycaster.intersectObjects(p.pieceMeshes);

          if (hits.length > 0) {
            self._clearSelections();
            self._addSelection(hits[0].object);
            self._updateInfo();
          }
        });

        var _hoverPending = false;
        canvas.addEventListener('mousemove', function(e) {
          if (_hoverPending) return;
          _hoverPending = true;
          var ex = e.clientX, ey = e.clientY;
          requestAnimationFrame(function() {
            _hoverPending = false;
            var rect = canvas.getBoundingClientRect();
            p.mouse.x = ((ex - rect.left) / rect.width) * 2 - 1;
            p.mouse.y = -((ey - rect.top) / rect.height) * 2 + 1;
            p.raycaster.setFromCamera(p.mouse, camera);
            var hits = p.raycaster.intersectObjects(p.pieceMeshes);
            canvas.style.cursor = hits.length > 0 ? 'pointer' : 'default';
          });
        });

        // Animate
        function animate() {
          p.animId = requestAnimationFrame(animate);
          controls.update();
          renderer.render(scene, camera);
        }
        animate();

        // Resize observer
        p.ro = new ResizeObserver(function() {
          var w2 = container.clientWidth;
          var h2 = container.clientHeight;
          if (w2 === 0 || h2 === 0) return;
          camera.aspect = w2 / h2;
          camera.updateProjectionMatrix();
          renderer.setSize(w2, h2);
        });
        p.ro.observe(container);
      },

      _loadScene: function() {
        var self = this;
        fetch('/rpc/scene_json', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Content-Profile': 'cad' },
          body: JSON.stringify({ p_drawing_id: this.drawingId })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          var pieces = Array.isArray(data) ? data : (data.pieces || []);
          self._buildMeshes(pieces);
          self._updateHud(pieces.length, data.total_volume || 0);
        })
        .catch(function(e) { self.hud = 'Erreur: ' + e.message; });
      },

      _buildMeshes: function(pieces) {
        var p = this._priv;
        var scene = p.scene;
        var allVerts = [];

        pieces.forEach(function(pc) {
          var verts = [];
          if (pc.mesh && pc.mesh.geometries) {
            pc.mesh.geometries.forEach(function(g) {
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

          var color = COLORS[pc.role] || COLORS.default;
          var mat = new THREE.MeshPhongMaterial({ color: color, flatShading: true, side: THREE.DoubleSide });
          var mesh = new THREE.Mesh(geom, mat);
          mesh.userData = { piece: true, id: pc.id, label: pc.label, role: pc.role,
            section: pc.section, length_mm: pc.length_mm, wood_type: pc.wood_type,
            group_id: pc.group_id || null, group_label: pc.group_label || null };
          scene.add(mesh);
          p.pieceMeshes.push(mesh);
          allVerts.push.apply(allVerts, verts);

          // Build group map
          if (pc.group_id) {
            if (!p.groupMap[pc.group_id]) p.groupMap[pc.group_id] = [];
            p.groupMap[pc.group_id].push(mesh);
          }
        });

        // Auto-center camera on first load
        if (allVerts.length > 0 && !p.cameraSet) {
          this._centerCamera(allVerts);
        }
      },

      _centerCamera: function(allVerts) {
        var p = this._priv;
        var box = new THREE.Box3();
        for (var i = 0; i < allVerts.length; i += 3) {
          box.expandByPoint(new THREE.Vector3(allVerts[i], allVerts[i+1], allVerts[i+2]));
        }
        var center = box.getCenter(new THREE.Vector3());
        var size = box.getSize(new THREE.Vector3()).length();
        p.controls.target.copy(center);
        p.camera.position.copy(center.clone().add(new THREE.Vector3(size * 0.8, size * 0.6, size * 0.8)));
        p.camera.lookAt(center);
        p.controls.update();
        p.cameraSet = true;
      },

      _addSelection: function(mesh) {
        var p = this._priv;
        if (p.selections.indexOf(mesh) >= 0) return;
        mesh._origColor = mesh.material.color.getHex();
        mesh.material.color.setHex(HIGHLIGHT);
        mesh.material.emissive = new THREE.Color(0x223344);
        p.selections.push(mesh);
        this.selCount = p.selections.length;
      },

      _removeSelection: function(idx) {
        var p = this._priv;
        var m = p.selections[idx];
        m.material.color.setHex(m._origColor);
        m.material.emissive = new THREE.Color(0x000000);
        p.selections.splice(idx, 1);
        this.selCount = p.selections.length;
        this._updateInfo();
      },

      _clearSelections: function() {
        var p = this._priv;
        p.selections.forEach(function(m) {
          m.material.color.setHex(m._origColor);
          m.material.emissive = new THREE.Color(0x000000);
        });
        p.selections = [];
        this.selCount = 0;
        this.info = null;
      },

      _updateHud: function(count, totalVolume) {
        this.hud = count + ' pi\u00e8ces \u2014 ' + parseFloat(totalVolume).toFixed(4) + ' m\u00b3 bois';
      },

      _updateInfo: function() {
        var p = this._priv;
        if (p.selections.length === 0) {
          this.info = null;
          this.$dispatch('cad-select', { pieces: [], group: null });
          return;
        }

        // Check if all selected pieces belong to the same group
        var gid = p.selections[0].userData.group_id;
        var allSameGroup = gid && p.selections.every(function(m) {
          return m.userData.group_id === gid;
        });

        var items = [];
        var allItems = [];
        var max = Math.min(p.selections.length, 4);
        for (var i = 0; i < p.selections.length; i++) {
          var d = p.selections[i].userData;
          var item = {
            role: d.role || '',
            label: d.label || 'Sans nom',
            section: d.section,
            length_mm: Math.round(d.length_mm || 0),
            wood_type: d.wood_type || '',
            id: d.id
          };
          allItems.push(item);
          if (i < max) items.push(item);
        }
        this.info = {
          items: items,
          extra: p.selections.length > max ? (p.selections.length - max) : 0,
          group_label: allSameGroup ? p.selections[0].userData.group_label : null,
          group_id: allSameGroup ? gid : null,
          group_count: allSameGroup ? p.selections.length : 0
        };

        // Dispatch event for other Alpine components on the page
        this.$dispatch('cad-select', {
          pieces: allItems,
          group: allSameGroup ? { id: gid, label: p.selections[0].userData.group_label } : null
        });
      },

      resetCamera: function() {
        var p = this._priv;
        p.cameraSet = false;
        var allVerts = [];
        p.pieceMeshes.forEach(function(m) {
          var pos = m.geometry.getAttribute('position');
          if (pos) {
            for (var i = 0; i < pos.count; i++) {
              allVerts.push(pos.getX(i), pos.getY(i), pos.getZ(i));
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
        this._priv.scene.traverse(function(obj) {
          if (obj.isMesh && obj.material) obj.material.wireframe = wf;
        });
      },

      copyContext: function() {
        var ctx = this._priv.selections.map(function(s) {
          var d = s.userData;
          return '#' + d.id + ' ' + (d.label || '?') + ' [' + d.role + '] ' + d.section + ' ' + Math.round(d.length_mm) + 'mm ' + d.wood_type;
        }).join('\n');
        navigator.clipboard.writeText(ctx);
      },

      // --- Methods called by cadPieceTree via events ---

      selectByIds: function(detail) {
        var ids = detail.pieceIds || [];
        this._clearSelections();
        var self = this;
        this._priv.pieceMeshes.forEach(function(m) {
          if (ids.indexOf(m.userData.id) >= 0) self._addSelection(m);
        });
        this._updateInfo();
      },

      toggleById: function(detail) {
        var pieceId = detail.pieceId;
        var visible = detail.visible;
        this._priv.pieceMeshes.forEach(function(m) {
          if (m.userData.id === pieceId) m.visible = visible;
        });
      },

      toggleGroupById: function(detail) {
        var groupId = detail.groupId;
        var visible = detail.visible;
        var p = this._priv;
        if (p.groupMap[groupId]) {
          p.groupMap[groupId].forEach(function(m) { m.visible = visible; });
        }
      }
    },

    events: {
      emit: ['cad-select'],
      listen: {}  // wired via Alpine @event.window attributes in HTML (no change)
    }
  });

  // ── 3D Piece Tree plugin ──────────────────────────────────────

  pgv.plugin('cadPieceTree', {

    data: function() {
      return {
        selectedIds: [],
        hiddenPieces: {},
        hiddenGroups: {}
      };
    },

    mount: function(el) {
      var self = this;
      el.querySelectorAll('.cad-tree-swatch[data-color]').forEach(function(swatch) {
        swatch.style.setProperty('--cad-swatch-color', swatch.dataset.color);
      });
      // Group selection via summary click delegation
      el.addEventListener('click', function(e) {
        var summary = e.target.closest('summary');
        if (summary) {
          var groupLi = summary.closest('[data-group]');
          if (groupLi) {
            self.selectGroup(parseInt(groupLi.dataset.group));
          }
        }
      });
    },

    methods: {

      selectPiece: function(pieceId) {
        this._clearTreeHighlight();
        this.selectedIds = [pieceId];
        this._highlightNode(pieceId);
        this.$dispatch('cad-piece-select', { pieceIds: [pieceId] });
      },

      selectGroup: function(groupId) {
        this._clearTreeHighlight();
        var ids = [];
        var container = this._rootEl.querySelector('[data-group="' + groupId + '"]');
        if (container) {
          container.querySelectorAll('[data-piece-id]').forEach(function(el) {
            var id = parseInt(el.dataset.pieceId);
            ids.push(id);
            el.classList.add('cad-tree-active');
          });
        }
        this.selectedIds = ids;
        this.$dispatch('cad-piece-select', { pieceIds: ids });
      },

      togglePiece: function(pieceId) {
        var wasHidden = !!this.hiddenPieces[pieceId];
        if (wasHidden) {
          delete this.hiddenPieces[pieceId];
        } else {
          this.hiddenPieces[pieceId] = true;
        }
        // Update eye icon
        var btn = this._rootEl.querySelector('[data-piece-id="' + pieceId + '"] .cad-tree-eye');
        if (btn) btn.textContent = wasHidden ? '\u25C9' : '\u25CB';
        this.$dispatch('cad-piece-toggle', { pieceId: pieceId, visible: wasHidden });
      },

      toggleGroup: function(groupId) {
        var wasHidden = !!this.hiddenGroups[groupId];
        if (wasHidden) {
          delete this.hiddenGroups[groupId];
        } else {
          this.hiddenGroups[groupId] = true;
        }
        // Update eye icons for all pieces in group
        var self = this;
        var container = this._rootEl.querySelector('[data-group="' + groupId + '"]');
        if (container) {
          container.querySelectorAll('.cad-tree-eye').forEach(function(btn) {
            btn.textContent = wasHidden ? '\u25C9' : '\u25CB';
          });
          container.querySelectorAll('[data-piece-id]').forEach(function(el) {
            var pid = parseInt(el.dataset.pieceId);
            if (wasHidden) {
              delete self.hiddenPieces[pid];
            } else {
              self.hiddenPieces[pid] = true;
            }
          });
        }
        this.$dispatch('cad-piece-toggle-group', { groupId: groupId, visible: wasHidden });
      },

      onViewerSelect: function(detail) {
        this._clearTreeHighlight();
        var pieces = detail.pieces || [];
        var self = this;
        var ids = [];
        pieces.forEach(function(pc) {
          ids.push(pc.id);
          self._highlightNode(pc.id);
        });
        this.selectedIds = ids;
      },

      _highlightNode: function(pieceId) {
        var node = this._rootEl.querySelector('[data-piece-id="' + pieceId + '"]');
        if (node) {
          node.classList.add('cad-tree-active');
          // Ensure parent details are open
          var parent = node.closest('details');
          if (parent) parent.open = true;
        }
      },

      _clearTreeHighlight: function() {
        this._rootEl.querySelectorAll('.cad-tree-active').forEach(function(el) {
          el.classList.remove('cad-tree-active');
        });
      }
    },

    events: {
      emit: ['cad-piece-select', 'cad-piece-toggle', 'cad-piece-toggle-group'],
      listen: {}  // wired via Alpine @event.window attributes in HTML (no change)
    }
  });

  // ── 2D Tree Explorer (simple Alpine component, no plugin needed) ──

  function registerCadTree() {
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
  }

  if (window.Alpine) {
    registerCadTree();
  } else {
    document.addEventListener('alpine:init', registerCadTree);
  }

})();
