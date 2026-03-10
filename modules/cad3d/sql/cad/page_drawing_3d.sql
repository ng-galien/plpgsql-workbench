CREATE OR REPLACE FUNCTION cad.page_drawing_3d(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing cad.drawing;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé');
  END IF;

  RETURN
    '<div id="cad-viewer" style="width:100%;height:70vh;background:#1a1a2e;border-radius:8px;overflow:hidden"></div>'
    || '<script type="module">'
    || 'import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.min.js";'
    || 'import {OrbitControls} from "https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/controls/OrbitControls.js";'

    -- Setup
    || 'const el=document.getElementById("cad-viewer");'
    || 'const W=el.clientWidth,H=el.clientHeight;'
    || 'const scene=new THREE.Scene();'
    || 'scene.background=new THREE.Color(0x1a1a2e);'
    || 'const camera=new THREE.PerspectiveCamera(50,W/H,1,100000);'
    || 'const renderer=new THREE.WebGLRenderer({antialias:true});'
    || 'renderer.setSize(W,H);'
    || 'renderer.setPixelRatio(window.devicePixelRatio);'
    || 'el.appendChild(renderer.domElement);'

    -- Lights
    || 'scene.add(new THREE.AmbientLight(0xffffff,0.5));'
    || 'const dl=new THREE.DirectionalLight(0xffffff,0.8);'
    || 'dl.position.set(2000,3000,4000);scene.add(dl);'
    || 'const dl2=new THREE.DirectionalLight(0xffffff,0.3);'
    || 'dl2.position.set(-1000,-2000,1000);scene.add(dl2);'

    -- Grid
    || 'const grid=new THREE.GridHelper(5000,50,0x444466,0x333355);'
    || 'grid.rotation.x=Math.PI/2;scene.add(grid);'

    -- Controls
    || 'const ctrl=new OrbitControls(camera,renderer.domElement);'
    || 'ctrl.enableDamping=true;'

    -- Colors by role
    || 'const COLORS={poteau:0xc8956c,traverse:0xa07850,chevron:0xd4a76a,lisse:0xb8925a,default:0xc8a882};'

    -- Render loop
    || 'function animate(){requestAnimationFrame(animate);ctrl.update();renderer.render(scene,camera)}'
    || 'animate();'

    -- Load scene
    || 'let lastJson="";'
    || 'async function loadScene(){'
    ||   'const r=await fetch("/rpc/scene_json",{method:"POST",'
    ||     'headers:{"Content-Type":"application/json","Accept":"application/json"},'
    ||     'body:JSON.stringify({p_drawing_id:' || p_id || '})});'
    ||   'const raw=await r.text();'
    ||   'if(raw===lastJson)return;lastJson=raw;'
    ||   'const pieces=JSON.parse(raw);'

    -- Clear old meshes
    ||   'scene.children.filter(c=>c.userData.piece).forEach(c=>scene.remove(c));'

    -- Build meshes from GeoJSON triangles
    ||   'let allVerts=[];'
    ||   'pieces.forEach(p=>{'
    ||     'const geom=new THREE.BufferGeometry();'
    ||     'const verts=[];'
    ||     'if(p.mesh&&p.mesh.geometries){'
    ||       'p.mesh.geometries.forEach(g=>{'
    ||         'if(g.coordinates&&g.coordinates[0]){'
    ||           'const ring=g.coordinates[0];'
    ||           'if(ring.length>=3){'
    ||             'verts.push(ring[0][0],ring[0][2],ring[0][1]);'  -- swap Y/Z for Three.js
    ||             'verts.push(ring[1][0],ring[1][2],ring[1][1]);'
    ||             'verts.push(ring[2][0],ring[2][2],ring[2][1]);'
    ||           '}'
    ||         '}'
    ||       '});'
    ||     '}'
    ||     'if(verts.length===0)return;'
    ||     'geom.setAttribute("position",new THREE.Float32BufferAttribute(verts,3));'
    ||     'geom.computeVertexNormals();'
    ||     'const color=COLORS[p.role]||COLORS.default;'
    ||     'const mat=new THREE.MeshPhongMaterial({color,flatShading:true});'
    ||     'const mesh=new THREE.Mesh(geom,mat);'
    ||     'mesh.userData.piece=true;'
    ||     'scene.add(mesh);'
    ||     'allVerts.push(...verts);'
    ||   '});'

    -- Center camera on model
    ||   'if(allVerts.length>0){'
    ||     'const box=new THREE.Box3();'
    ||     'for(let i=0;i<allVerts.length;i+=3){'
    ||       'box.expandByPoint(new THREE.Vector3(allVerts[i],allVerts[i+1],allVerts[i+2]));'
    ||     '}'
    ||     'const center=box.getCenter(new THREE.Vector3());'
    ||     'const size=box.getSize(new THREE.Vector3()).length();'
    ||     'ctrl.target.copy(center);'
    ||     'camera.position.copy(center.clone().add(new THREE.Vector3(size*0.8,size*0.6,size*0.8)));'
    ||     'camera.lookAt(center);'
    ||     'ctrl.update();'
    ||   '}'
    || '}'

    -- Initial load + polling
    || 'loadScene();'
    || 'setInterval(loadScene,1500);'

    -- Resize
    || 'window.addEventListener("resize",()=>{'
    ||   'const w=el.clientWidth,h=el.clientHeight;'
    ||   'camera.aspect=w/h;camera.updateProjectionMatrix();'
    ||   'renderer.setSize(w,h);'
    || '});'

    || '</script>';
END;
$function$;
