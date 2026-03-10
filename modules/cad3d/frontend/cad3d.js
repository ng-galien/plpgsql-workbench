/**
 * cad3d — Alpine.js components for CAD 3D module
 *
 * Registers Alpine components that can be used in PL/pgSQL fragments:
 *   <div x-data="cadViewer" x-init="load(drawingId)">
 *   <div x-data="cadMinimap" x-init="load(drawingId)">
 */

document.addEventListener('alpine:init', function() {

  // --- 3D Viewer component ---
  Alpine.data('cadViewer', function() {
    return {
      drawingId: null,
      pieces: [],
      selected: [],
      wireframe: false,
      scene: null,
      camera: null,
      renderer: null,

      load: function(id) {
        this.drawingId = id;
        var self = this;
        var canvas = this.$refs.viewport;
        if (!canvas) return;

        // Lazy-load Three.js
        if (typeof THREE === 'undefined') {
          var s = document.createElement('script');
          s.src = 'https://cdn.jsdelivr.net/npm/three@0.160/build/three.min.js';
          s.onload = function() {
            var s2 = document.createElement('script');
            s2.src = 'https://cdn.jsdelivr.net/npm/three@0.160/examples/js/controls/OrbitControls.js';
            s2.onload = function() { self._init3d(canvas); self._loadScene(); };
            document.head.appendChild(s2);
          };
          document.head.appendChild(s);
        } else {
          this._init3d(canvas);
          this._loadScene();
        }
      },

      _init3d: function(canvas) {
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0xf0f0f0);
        this.camera = new THREE.PerspectiveCamera(50, canvas.clientWidth / canvas.clientHeight, 1, 50000);
        this.camera.position.set(3000, 2000, 4000);
        this.renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
        this.renderer.setSize(canvas.clientWidth, canvas.clientHeight);

        var controls = new THREE.OrbitControls(this.camera, canvas);
        controls.target.set(0, 1000, 0);
        controls.update();

        // Lights
        this.scene.add(new THREE.AmbientLight(0xffffff, 0.6));
        var dir = new THREE.DirectionalLight(0xffffff, 0.8);
        dir.position.set(5000, 8000, 5000);
        this.scene.add(dir);

        // Ground grid
        this.scene.add(new THREE.GridHelper(10000, 20, 0xcccccc, 0xeeeeee));

        var self = this;
        var renderer = this.renderer;
        var camera = this.camera;
        var scene = this.scene;
        function animate() {
          requestAnimationFrame(animate);
          renderer.render(scene, camera);
        }
        animate();

        // Resize
        window.addEventListener('resize', function() {
          camera.aspect = canvas.clientWidth / canvas.clientHeight;
          camera.updateProjectionMatrix();
          renderer.setSize(canvas.clientWidth, canvas.clientHeight);
        });
      },

      _loadScene: function() {
        var self = this;
        fetch('/rpc/scene_json', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ p_drawing_id: this.drawingId })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          self.pieces = data.pieces || [];
          self._buildMeshes();
        });
      },

      _buildMeshes: function() {
        var self = this;
        this.pieces.forEach(function(p) {
          var geom = new THREE.BoxGeometry(
            p.bbox.dx || 80, p.bbox.dz || 80, p.bbox.dy || 80
          );
          var mat = new THREE.MeshLambertMaterial({
            color: self._roleColor(p.role),
            wireframe: self.wireframe
          });
          var mesh = new THREE.Mesh(geom, mat);
          // PostGIS [x,y,z] → Three.js [x,z,-y]
          mesh.position.set(
            (p.bbox.xmin + p.bbox.dx / 2),
            (p.bbox.zmin + p.bbox.dz / 2),
            -(p.bbox.ymin + p.bbox.dy / 2)
          );
          mesh.userData = p;
          self.scene.add(mesh);
        });
      },

      _roleColor: function(role) {
        var colors = {
          poteau: 0x8B4513, traverse: 0xCD853F, lisse: 0xDEB887,
          chevron: 0xD2691E, faitiere: 0xA0522D
        };
        return colors[role] || 0x999999;
      },

      resetCamera: function() {
        this.camera.position.set(3000, 2000, 4000);
        this.camera.lookAt(0, 1000, 0);
      },

      toggleWireframe: function() {
        this.wireframe = !this.wireframe;
        var wf = this.wireframe;
        this.scene.traverse(function(obj) {
          if (obj.isMesh && obj.material) obj.material.wireframe = wf;
        });
      }
    };
  });

});
