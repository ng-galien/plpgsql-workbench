CREATE OR REPLACE FUNCTION pgv_qa.page_settings()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_root text;
BEGIN
  SELECT value INTO v_root FROM pgv_qa.setting WHERE key = 'documentsRoot';
  RETURN
    '<section><h4>Documents</h4>'
    || '<form data-rpc="save_settings">'
    || '<label>Repertoire racine</label>'
    || '<div class="grid">'
    || '<input id="documentsRoot" name="p_documentsroot" type="text"'
    || ' value="' || coalesce(pgv.esc(v_root), '') || '"'
    || ' placeholder="/chemin/vers/documents" required>'
    || '<button type="button" class="outline"'
    || ' data-dialog="folder-picker"'
    || ' data-src="' || CASE WHEN v_root IS NOT NULL THEN '/api/browse?path=' || pgv.esc(v_root) ELSE '/api/browse' END || '"'
    || ' data-target="documentsRoot">Parcourir</button>'
    || '</div>'
    || '<small>Dossier contenant les documents a indexer</small>'
    || '<button type="submit">Enregistrer</button>'
    || '</form></section>'
    || '<section><h4>Systeme</h4>'
    || pgv.dl('Version', '0.1.0', 'PostgreSQL', version())
    || '</section>';
END;
$function$;
