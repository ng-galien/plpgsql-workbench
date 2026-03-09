CREATE OR REPLACE FUNCTION app.page_settings(p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_docs_root text;
  v_body text;
  v_browse_path text;
BEGIN
  -- Read current config
  SELECT value INTO v_docs_root
  FROM workbench.config
  WHERE app = 'docman' AND key = 'documentsRoot';

  v_browse_path := coalesce(v_docs_root, '/');

  v_body := '<article><header>Documents</header>'
    || '<form hx-post="/rpc/save_settings" hx-target="#app" hx-swap="innerHTML">'
    || '<label>Repertoire des documents <sup>*</sup>'
    || '<div class="grid">'
    || '<input id="documentsRoot" name="p_documentsroot" type="text" value="' || coalesce(pgv.esc(v_docs_root), '') || '" required>'
    || '<button type="button" class="outline"'
    || ' hx-get="/api/browse?path=' || pgv.esc(v_browse_path) || '"'
    || ' hx-target="#folder-list"'
    || ' hx-swap="innerHTML"'
    || ' onclick="document.getElementById(''folder-picker'').style.display=''block''"'
    || '>Parcourir</button>'
    || '</div></label>'
    || '<div id="folder-picker" style="display:none">'
    || '<article>'
    || '<div id="folder-list"></div>'
    || '</article>'
    || '</div>'
    || '<button type="submit">Enregistrer</button>'
    || '</form></article>';

  RETURN pgv.page('Configuration', '/settings', app.nav_items(), v_body);
END;
$function$;
