CREATE OR REPLACE FUNCTION app.page_settings(p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_docs_root text;
  v_browse_path text;
  v_css text;
  v_body text;
BEGIN
  SELECT value INTO v_docs_root
  FROM workbench.config
  WHERE app = 'docman' AND key = 'documentsRoot';

  v_browse_path := coalesce(v_docs_root, '/');

  -- Scoped styles
  v_css := '<style>'
    || '.settings-section { margin-bottom: 2rem; }'
    || '.settings-section > header { font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--pico-muted-color); font-weight: 600; margin-bottom: 0.75rem; padding-bottom: 0.5rem; border-bottom: 1px solid var(--pico-muted-border-color); }'
    || '.path-input-group { display: flex; gap: 0.5rem; align-items: stretch; }'
    || '.path-input-group input { flex: 1; margin-bottom: 0; }'
    || '.path-input-group button { margin-bottom: 0; white-space: nowrap; flex-shrink: 0; }'
    || '.settings-actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.5rem; }'
    || '.settings-actions button { width: auto; }'
    || '#folder-dialog article { margin: 0; width: min(90vw, 560px); }'
    || '#folder-dialog .folder-path { font-family: monospace; font-size: 0.85rem; background: var(--pico-code-background-color); padding: 0.5rem 0.75rem; border-radius: var(--pico-border-radius); margin-bottom: 0.75rem; word-break: break-all; }'
    || '#folder-dialog .folder-list { max-height: 50vh; overflow-y: auto; border: 1px solid var(--pico-muted-border-color); border-radius: var(--pico-border-radius); }'
    || '#folder-dialog .folder-list a { display: flex; align-items: center; gap: 0.5rem; padding: 0.6rem 0.75rem; text-decoration: none; color: var(--pico-color); border-bottom: 1px solid var(--pico-muted-border-color); transition: background 0.15s; }'
    || '#folder-dialog .folder-list a:last-child { border-bottom: none; }'
    || '#folder-dialog .folder-list a:hover { background: var(--pico-primary-focus); }'
    || '#folder-dialog .folder-list .folder-icon { opacity: 0.6; flex-shrink: 0; }'
    || '#folder-dialog .folder-list .folder-up { font-weight: 600; color: var(--pico-muted-color); }'
    || '#folder-dialog .folder-empty { padding: 2rem; text-align: center; color: var(--pico-muted-color); }'
    || '#folder-dialog footer { display: flex; justify-content: flex-end; gap: 0.5rem; }'
    || '#folder-dialog footer button { width: auto; margin-bottom: 0; }'
    || '.info-grid { display: grid; grid-template-columns: auto 1fr; gap: 0.25rem 1rem; font-size: 0.9rem; }'
    || '.info-grid dt { color: var(--pico-muted-color); }'
    || '.info-grid dd { margin: 0; }'
    || '.htmx-request .save-label { display: none; }'
    || '.save-spinner { display: none; }'
    || '.htmx-request .save-spinner { display: inline; }'
    || '</style>';

  -- Settings form (hx-disinherit stops p_path from parent #app hx-vals)
  v_body := v_css

    -- Documents section
    || '<section class="settings-section">'
    || '<header>Documents</header>'
    || '<form hx-post="/rpc/save_settings" hx-swap="none" hx-disinherit="hx-vals">'
    || '<label>Repertoire racine des documents</label>'
    || '<div class="path-input-group">'
    || '<input id="documentsRoot" name="p_documentsroot" type="text" '
    || 'value="' || coalesce(pgv.esc(v_docs_root), '') || '" '
    || 'placeholder="/chemin/vers/vos/documents" required>'
    || '<button type="button" class="outline" '
    || 'onclick="document.getElementById(''folder-dialog'').showModal()" '
    || 'hx-get="/api/browse?path=' || pgv.esc(v_browse_path) || '" '
    || 'hx-target="#folder-content" hx-swap="innerHTML"'
    || '>Parcourir</button>'
    || '</div>'
    || '<small>Dossier contenant les documents a indexer (factures, contrats, courriers...)</small>'
    || '<div class="settings-actions">'
    || '<button type="submit"><span class="save-label">Enregistrer</span><span class="save-spinner" aria-busy="true">Enregistrement...</span></button>'
    || '</div>'
    || '</form>'
    || '</section>'

    -- System info section
    || '<section class="settings-section">'
    || '<header>Systeme</header>'
    || '<dl class="info-grid">'
    || '<dt>Version</dt><dd>0.1.0</dd>'
    || '<dt>Base</dt><dd><code>' || coalesce(current_setting('application_name', true), 'postgres') || '@' || inet_server_addr()::text || '</code></dd>'
    || '<dt>Documents indexes</dt><dd>' || (SELECT count(*)::text FROM docstore.file) || '</dd>'
    || '<dt>Documents docman</dt><dd>' || (SELECT count(*)::text FROM docman.document) || '</dd>'
    || '<dt>Labels</dt><dd>' || (SELECT count(*)::text FROM docman.label) || '</dd>'
    || '</dl>'
    || '</section>'

    -- Folder picker dialog
    || '<dialog id="folder-dialog">'
    || '<article>'
    || '<header>'
    || '<button aria-label="Fermer" rel="prev" onclick="document.getElementById(''folder-dialog'').close()"></button>'
    || '<strong>Selectionner un dossier</strong>'
    || '</header>'
    || '<div id="folder-content"></div>'
    || '<footer>'
    || '<button class="secondary" onclick="document.getElementById(''folder-dialog'').close()">Annuler</button>'
    || '<button id="folder-select-btn" onclick="'
    || 'var p=document.getElementById(''folder-current-path'');'
    || 'if(p){document.getElementById(''documentsRoot'').value=p.textContent;}'
    || 'document.getElementById(''folder-dialog'').close();"'
    || '>Selectionner</button>'
    || '</footer>'
    || '</article>'
    || '</dialog>';

  RETURN pgv.page('Configuration', '/settings', app.nav_items(), v_body);
END;
$function$;
