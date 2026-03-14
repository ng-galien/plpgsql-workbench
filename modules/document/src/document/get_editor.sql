CREATE OR REPLACE FUNCTION document.get_editor(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c document.canvas;
BEGIN
  SELECT * INTO v_c FROM document.canvas WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_c IS NULL THEN
    RETURN pgv.empty(pgv.t('document.canvas_not_found'));
  END IF;

  -- The data-illustrator attribute triggers the shell to load the illustrator bundle
  RETURN '<div data-illustrator="' || p_id::text || '">'

    -- Loader
    || '<div class="loader" id="loader"><div class="loader-content">'
    || '<h1 class="loader-title">' || pgv.esc(v_c.name) || '</h1>'
    || '<div class="loader-line"><div class="loader-pulse"></div></div>'
    || '<p class="loader-subtitle">' || pgv.esc(v_c.format || '') || ' ' || pgv.esc(v_c.orientation || '') || '</p>'
    || '</div></div>'

    -- Menu bar
    || '<header class="menu-bar" id="menuBar">'
    || '<div class="menu-section menu-section--brand"><span class="menu-app-name">' || pgv.esc(v_c.name) || '</span><div class="status-dot" id="statusDot"></div></div>'
    || '<div class="menu-sep"></div>'
    || '<div class="menu-section menu-section--doc"><button class="doc-selector" id="docSelector"><span class="doc-selector-label" id="docSelectorLabel">' || pgv.esc(v_c.name) || '</span><svg class="doc-selector-chevron" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></button><div class="doc-dropdown" id="docDropdown"><div class="doc-dropdown-list" id="docDropdownList"></div></div></div>'
    || '<div class="menu-sep"></div>'
    || '<div class="menu-section"><div class="menu-btn-group"><button class="menu-btn" id="btnUndo" data-tooltip="Annuler"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 7h7a3 3 0 0 1 0 6H9"/><path d="M6 4L3 7l3 3"/></svg></button><button class="menu-btn" id="btnRedo" data-tooltip="Refaire"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M13 7H6a3 3 0 0 0 0 6h1"/><path d="M10 4l3 3-3 3"/></svg></button></div><button class="menu-btn" id="btnSave" data-tooltip="Sauvegarder"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 3a1 1 0 0 1 1-1h7l3 3v8a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V3z"/><path d="M5 2v4h5V2"/><path d="M5 9h6v4H5z"/></svg></button></div>'
    || '<div class="menu-sep"></div>'
    || '<div class="menu-section"><div class="menu-btn-group"><button class="menu-btn active" id="toggleSnap" data-tooltip="Magnetisme"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M8 1v14M1 8h14"/><circle cx="8" cy="8" r="3"/></svg></button><button class="menu-btn active" id="toggleBleed" data-tooltip="Fond perdu"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="2" width="12" height="12" rx="1" stroke-dasharray="2 1.5"/><rect x="4" y="4" width="8" height="8" rx="0.5"/></svg></button><button class="menu-btn active" id="toggleNames" data-tooltip="Inspecteur"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="3" width="12" height="10" rx="1"/><path d="M5 6h6M5 9h3"/></svg></button></div><button class="menu-btn" id="toggleLock" data-tooltip="Verrouiller"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="7" width="10" height="7" rx="1.5"/><path d="M5 7V5a3 3 0 0 1 6 0v2"/></svg></button></div>'
    || '<div class="menu-sep"></div>'
    || '<div class="menu-section menu-section--zoom"><span class="zoom-label" id="zoomLabel">100%</span><input class="zoom-slider" id="zoomSlider" type="range" min="15" max="400" value="100" step="5"></div>'
    || '<div class="menu-spacer"></div>'
    || '<div class="menu-section"><button class="menu-btn menu-btn--export" id="btnExportSvg" data-tooltip="SVG">SVG</button><button class="menu-btn menu-btn--export" id="btnExportPdf" data-tooltip="PDF">PDF</button></div>'
    || '</header>'

    -- Workspace
    || '<div class="workspace" id="workspace">'
    || '<aside class="layers-panel" id="layersPanel"><div class="panel-header"><span class="panel-title">Structure</span><span class="panel-count" id="layersCount">0</span><button class="panel-collapse-btn" id="collapseLayersBtn"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 4l-4 4 4 4"/></svg></button></div><div class="panel-body" id="panelBodyLayers"><ul class="tree" id="tree"></ul></div><div class="layers-actions" id="layersActions"><button class="action-btn" id="actionDelete"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 4h10M6 4V3a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v1m2 0v9a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4h10z"/></svg></button><button class="action-btn" id="actionDuplicate"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="5" width="8" height="8" rx="1"/><path d="M3 11V3a1 1 0 0 1 1-1h8"/></svg></button><button class="action-btn" id="actionMoveUp"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 12V4m0 0L5 7m3-3l3 3"/></svg></button><button class="action-btn" id="actionMoveDown"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 4v8m0 0l-3-3m3 3l3-3"/></svg></button></div></aside>'
    || '<div class="resize-handle-v" id="resizeHandleL"></div>'
    || '<main class="canvas-viewport" id="canvasViewport"><div class="svg-wrap"><svg id="canvas"></svg></div></main>'
    || '<div class="resize-handle-v" id="resizeHandleR"></div>'
    || '<aside class="properties-panel" id="propsPanel"><div class="panel-header"><span class="panel-title" id="propsTitle">Proprietes</span><button class="panel-collapse-btn" id="collapsePropsBtn"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 4l4 4-4 4"/></svg></button></div><div class="panel-body" id="propsContent"></div></aside>'
    || '</div>'

    -- Photo library
    || '<div class="resize-handle-h" id="resizeHandleH"></div>'
    || '<div class="photo-library" id="photoPanel"><div class="photo-header"><button class="photo-collapse-btn" id="collapsePhotoBtn"><svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M2.5 4l3.5 3.5L9.5 4"/></svg></button><span class="photo-title">Bibliotheque</span><span class="photo-count" id="photoCount"></span></div><div class="photo-upload-zone" id="uploadZone"><input type="file" id="uploadInput" accept="image/*" multiple><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 5v14m-7-7h14"/></svg></div><div class="photo-strip" id="photoGrid"></div></div>'

    -- Meta overlay
    || '<div class="meta-overlay" id="metaOverlay"><button class="meta-close" id="metaClose">&times;</button><div class="meta-card" id="metaCard"></div></div>'

    -- Image editor modal
    || '<div class="ie-overlay" id="imageEditorOverlay"><div class="ie-card"><div class="ie-header"><span class="ie-header-title">Modifier l''image</span><span class="ie-header-path"></span><button class="ie-close">&times;</button></div><div class="ie-body"><div class="ie-preview" id="iePreview"></div><div class="ie-controls" id="ieControls"></div></div><div class="ie-footer"><button class="ie-btn" id="ieCancel">Annuler</button><button class="ie-btn ie-btn-primary" id="ieApply">Appliquer</button></div></div></div>'

    || '</div>';
END;
$function$;
