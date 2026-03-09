CREATE OR REPLACE FUNCTION app.page_settings(p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_docs_root text;
  v_body text;
BEGIN
  -- Handle POST: save config
  IF p_body ? 'documentsRoot' THEN
    INSERT INTO workbench.config (app, key, value)
    VALUES ('docman', 'documentsRoot', p_body->>'documentsRoot')
    ON CONFLICT (app, key) DO UPDATE SET value = EXCLUDED.value;

    PERFORM set_config('response.headers',
      '[{"HX-Trigger": "configSaved"}]', true);
  END IF;

  -- Read current config
  SELECT value INTO v_docs_root
  FROM workbench.config
  WHERE app = 'docman' AND key = 'documentsRoot';

  v_body := '<article><header>Documents</header>'
    || '<form hx-post="/rpc/page?p_path=/settings" hx-target="#app" hx-swap="innerHTML">'
    || '<label>Repertoire des documents <sup>*</sup>'
    || '<div class="grid">'
    || '<input id="documentsRoot" name="documentsRoot" type="text" value="' || coalesce(pgv.esc(v_docs_root), '') || '" required>'
    || '<button type="button" onclick="document.getElementById(''folder-picker'').style.display=document.getElementById(''folder-picker'').style.display===''none''?''block'':''none''" class="outline">Parcourir</button>'
    || '</div></label>'
    || '<div id="folder-picker" style="display:none">'
    || '<article>'
    || '<div id="folder-list" hx-get="/api/browse?path=' || coalesce(pgv.esc(v_docs_root), '/') || '" hx-trigger="load" hx-swap="innerHTML"></div>'
    || '</article>'
    || '</div>'
    || '<button type="submit">Enregistrer</button>'
    || '</form></article>';

  RETURN pgv.page('Configuration', '/settings', app.nav_items(), v_body);
END;
$function$;
