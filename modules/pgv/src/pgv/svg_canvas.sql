CREATE OR REPLACE FUNCTION pgv.svg_canvas(p_svg text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
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
    || '<div class="pgv-canvas-vp" id="' || v_id || '_vp" style="height:' || v_height || '">'
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
      || '</div>';
  END IF;

  v_html := v_html || '</div>';

  v_js := $JS$
(function(){
  var id="__ID__",
      vp=document.getElementById(id+"_vp"),
      svg=vp&&vp.querySelector("svg"),
      zl=document.getElementById(id+"_zl");
  if(!vp||!svg||typeof panzoom==="undefined")return;
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
  if(fb)fb.onclick();
})();
$JS$;

  v_js := replace(v_js, '__ID__', v_id);
  v_html := v_html || pgv.script(v_js);

  RETURN v_html;
END;
$function$;
