CREATE OR REPLACE FUNCTION pgv.svg_canvas(p_svg text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_id text := 'sc_' || substr(md5(random()::text), 1, 8);
  v_height text := coalesce(p_options->>'height', '60vh');
  v_toolbar boolean := coalesce((p_options->>'toolbar')::boolean, true);
  v_html text;
  v_js text;
BEGIN
  IF p_svg IS NULL OR p_svg = '' THEN RETURN ''; END IF;

  v_html := '<div class="pgv-canvas" id="' || v_id || '">'
    || '<div class="pgv-canvas-vp" id="' || v_id || '_vp" data-height="' || pgv.esc(v_height) || '">'
    || p_svg
    || '</div>';

  IF v_toolbar THEN
    v_html := v_html
      || '<div class="pgv-canvas-bar">'
      || '<button class="pgv-canvas-btn" id="' || v_id || '_out" title="Zoom out">&minus;</button>'
      || '<span class="pgv-canvas-zoom" id="' || v_id || '_zl">100%</span>'
      || '<button class="pgv-canvas-btn" id="' || v_id || '_in" title="Zoom in">+</button>'
      || '<span class="pgv-canvas-sep"></span>'
      || '<button class="pgv-canvas-btn" id="' || v_id || '_fit" title="Ajuster">Fit</button>'
      || '<button class="pgv-canvas-btn" id="' || v_id || '_reset" title="1:1">1:1</button>'
      || '<span class="pgv-canvas-sep"></span>'
      || '<button class="pgv-canvas-btn" id="' || v_id || '_print" title="' || pgv.t('pgv.print') || '">&#x1F5B6;</button>'
      || '</div>';
  END IF;

  IF NOT v_toolbar THEN
    v_html := v_html
      || '<button class="pgv-print-btn" id="' || v_id || '_print2" title="' || pgv.t('pgv.print') || '">&#x1F5B6;</button>';
  END IF;

  v_html := v_html || '</div>';

  v_js := $JS$
(function(){
  var id="__ID__",
      vp=document.getElementById(id+"_vp"),
      svg=vp&&vp.querySelector("svg"),
      zl=document.getElementById(id+"_zl");
  if(!vp||!svg||typeof panzoom==="undefined")return;
  if(vp.dataset.height)vp.style.height=vp.dataset.height;
  var pz=panzoom(svg,{maxZoom:20,minZoom:0.05,smoothScroll:false,bounds:true,boundsPadding:0.2});
  function upd(){if(zl)zl.textContent=Math.round(pz.getTransform().scale*100)+"%";}
  pz.on("zoom",upd);
  pz.on("transform",upd);
  var zi=document.getElementById(id+"_in"),
      zo=document.getElementById(id+"_out"),
      fb=document.getElementById(id+"_fit"),
      rb=document.getElementById(id+"_reset");
  if(zi)zi.onclick=function(){pz.smoothZoom(vp.clientWidth/2,vp.clientHeight/2,1.3);};
  if(zo)zo.onclick=function(){pz.smoothZoom(vp.clientWidth/2,vp.clientHeight/2,0.7);};
  if(rb)rb.onclick=function(){pz.moveTo(0,0);pz.zoomAbs(0,0,1);upd();};
  if(fb)fb.onclick=function(){
    var bb=svg.getBBox(),vw=vp.clientWidth,vh=vp.clientHeight,
        sc=Math.min(vw/(bb.width+bb.x*2),vh/(bb.height+bb.y*2))*0.9,
        ox=(vw-bb.width*sc)/2-bb.x*sc,
        oy=(vh-bb.height*sc)/2-bb.y*sc;
    pz.zoomAbs(0,0,sc);pz.moveTo(ox,oy);upd();
  };
  if(fb){if(vp.clientWidth>0)fb.onclick();else{var io=new IntersectionObserver(function(es){if(es[0].isIntersecting&&vp.clientWidth>0){fb.onclick();io.disconnect();}});io.observe(vp);}}
  var pb=document.getElementById(id+"_print")||document.getElementById(id+"_print2");
  if(pb)pb.onclick=function(){var s=vp.querySelector("svg");if(!s)return;var c=s.cloneNode(true);c.removeAttribute("style");var bb=s.getBBox();var pad=10;c.setAttribute("viewBox",(bb.x-pad)+" "+(bb.y-pad)+" "+(bb.width+pad*2)+" "+(bb.height+pad*2));c.setAttribute("width",bb.width+pad*2);c.setAttribute("height",bb.height+pad*2);c.setAttribute("xmlns","http://www.w3.org/2000/svg");c.setAttribute("xmlns:xlink","http://www.w3.org/1999/xlink");var imgs=c.querySelectorAll("image");if(!imgs.length){var bl=new Blob([c.outerHTML],{type:"image/svg+xml"});var al=document.createElement("a");al.href=URL.createObjectURL(bl);al.download="export.svg";al.click();URL.revokeObjectURL(al.href);return;}var done=0;imgs.forEach(function(img){var url=img.getAttribute("href")||img.getAttributeNS("http://www.w3.org/1999/xlink","href");if(!url||url.startsWith("data:")){done++;if(done===imgs.length)dl();return;}fetch(url).then(function(r){return r.blob();}).then(function(blob){var rd=new FileReader();rd.onload=function(){img.setAttribute("href",rd.result);img.removeAttributeNS("http://www.w3.org/1999/xlink","href");done++;if(done===imgs.length)dl();};rd.readAsDataURL(blob);}).catch(function(){done++;if(done===imgs.length)dl();});});function dl(){var bl=new Blob([c.outerHTML],{type:"image/svg+xml"});var al=document.createElement("a");al.href=URL.createObjectURL(bl);al.download="export.svg";al.click();URL.revokeObjectURL(al.href);}};
})();
$JS$;

  v_js := replace(v_js, '__ID__', v_id);
  v_html := v_html || pgv.script(v_js);

  RETURN v_html;
END;
$function$;
