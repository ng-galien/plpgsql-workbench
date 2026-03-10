CREATE OR REPLACE FUNCTION cad.fragment_viewer(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '<div x-data="cadViewer" x-init="load(' || p_drawing_id || ')" class="cad-viewer">'
    || '<div x-ref="viewport" class="cad-viewport"></div>'
    -- HUD
    || '<div class="cad-hud" x-text="hud"></div>'
    -- Toolbar
    || '<div class="cad-toolbar">'
    || '<button @click="resetCamera()">Reset</button>'
    || '<button @click="toggleWireframe()" x-text="wireframe ? ''Solid'' : ''Wire''">Wire</button>'
    || '<button @click="copyContext()" x-show="selections.length > 0">Copier</button>'
    || '</div>'
    -- Info panel
    || '<div class="cad-info" x-show="info" x-transition>'
    || '<template x-for="(item, idx) in (info ? info.items : [])" :key="idx">'
    || '<div>'
    || '<hr class="cad-info-sep" x-show="idx > 0">'
    || '<span class="cad-info-role" x-text="item.role"></span><br>'
    || '<span class="cad-info-label" x-text="item.label"></span><br>'
    || '<span class="cad-info-dim" x-text="item.section + '' — '' + item.length_mm + '' mm — '' + item.wood_type"></span><br>'
    || '<span class="cad-info-id" x-text="''#'' + item.id"></span>'
    || '</div>'
    || '</template>'
    || '<div class="cad-info-extra" x-show="info && info.extra > 0" x-text="''+ '' + (info ? info.extra : 0) + '' autres''"></div>'
    || '</div>'
    || '</div>';
END;
$function$;
