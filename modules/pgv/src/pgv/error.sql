CREATE OR REPLACE FUNCTION pgv.error(p_status text, p_title text, p_detail text DEFAULT NULL::text, p_hint text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_html text;
BEGIN
  v_html := '<article class="pgv-error">'
    || '<header><strong>' || pgv.esc(p_status) || E' \u2014 ' || pgv.esc(p_title) || '</strong></header>';
  IF p_detail IS NOT NULL THEN v_html := v_html || '<p>' || pgv.esc(p_detail) || '</p>'; END IF;
  IF p_hint IS NOT NULL THEN v_html := v_html || '<p><small>' || pgv.esc(p_hint) || '</small></p>'; END IF;
  v_html := v_html || '<footer><a href="#" class="pgv-error-report" onclick="'
    || 'var desc=this.closest(''.pgv-error'').textContent.trim();'
    || 'var dlg=this.closest(''dialog'');if(dlg)dlg.close();'
    || 'var d=Alpine.$data(document.querySelector(''[x-data]''));'
    || 'd.issue={open:true,desc:desc,type:''bug''};'
    || 'return false;">Signaler ce bug</a></footer>';
  v_html := v_html || '</article>';
  RETURN v_html;
END;
$function$;
