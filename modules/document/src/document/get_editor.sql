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

  -- data-illustrator triggers the shell to load D3 + app.js bundle
  -- x-data="illustrator" activates the Alpine bridge component
  RETURN '<div data-illustrator="' || p_id::text || '" x-data="illustrator">'

    -- Loader
    || '<div class="loader" id="loader" x-show="phase === ''loading''" x-transition.opacity><div class="loader-content">'
    || '<h1 class="loader-title">' || pgv.esc(v_c.name) || '</h1>'
    || '<div class="loader-line"><div class="loader-pulse"></div></div>'
    || '</div></div>'

    -- Menu bar
    || '<header class="menu-bar" id="menuBar">'
    || '<div class="menu-section menu-section--brand"><span class="menu-app-name" x-text="canvas?.name || ''-''">' || pgv.esc(v_c.name) || '</span><div class="status-dot" id="statusDot"></div></div>'
    || '<div class="menu-sep"></div>'

    -- Doc selector
    || '<div class="menu-section menu-section--doc"><button class="doc-selector" @click="toggleDocDropdown()"><span class="doc-selector-label" x-text="canvas?.name || ''Aucun document''"></span><svg class="doc-selector-chevron" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></button>'
    || '<div class="doc-dropdown" x-show="docDropdownOpen" @click.outside="docDropdownOpen=false" x-transition>'
    || '<template x-for="doc in docList" :key="doc.id"><button class="doc-dropdown-item" @click="loadDoc(doc.id)" x-text="doc.name"></button></template>'
    || '</div></div>'
    || '<div class="menu-sep"></div>'

    -- Undo/Redo/Save
    || '<div class="menu-section"><div class="menu-btn-group">'
    || '<button class="menu-btn" @click="undo()" data-tooltip="Annuler"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 7h7a3 3 0 0 1 0 6H9"/><path d="M6 4L3 7l3 3"/></svg></button>'
    || '<button class="menu-btn" @click="redo()" data-tooltip="Refaire"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M13 7H6a3 3 0 0 0 0 6h1"/><path d="M10 4l3 3-3 3"/></svg></button>'
    || '</div></div>'
    || '<div class="menu-sep"></div>'

    -- Toggle buttons
    || '<div class="menu-section"><div class="menu-btn-group">'
    || '<button class="menu-btn" :class="{active: snapEnabled}" @click="toggleSnap()" data-tooltip="Magnetisme"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M8 1v14M1 8h14"/><circle cx="8" cy="8" r="3"/></svg></button>'
    || '<button class="menu-btn" :class="{active: showBleed}" @click="toggleShowBleed()" data-tooltip="Fond perdu"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="2" width="12" height="12" rx="1" stroke-dasharray="2 1.5"/><rect x="4" y="4" width="8" height="8" rx="0.5"/></svg></button>'
    || '<button class="menu-btn" :class="{active: showNames}" @click="toggleShowNames()" data-tooltip="Inspecteur"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="3" width="12" height="10" rx="1"/><path d="M5 6h6M5 9h3"/></svg></button>'
    || '</div>'
    || '<button class="menu-btn" :class="{active: documentLocked}" @click="toggleLock()" data-tooltip="Verrouiller"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="7" width="10" height="7" rx="1.5"/><path d="M5 7V5a3 3 0 0 1 6 0v2"/></svg></button>'
    || '</div>'
    || '<div class="menu-sep"></div>'

    -- Zoom
    || '<div class="menu-section menu-section--zoom"><span class="zoom-label" id="zoomLabel" x-text="zoomPercent"></span><input class="zoom-slider" id="zoomSlider" type="range" min="15" max="400" :value="zoom*100" @input="setZoom(+$event.target.value)" step="5"></div>'
    || '<div class="menu-spacer"></div>'

    -- Export
    || '<div class="menu-section"><button class="menu-btn menu-btn--export" data-tooltip="SVG">SVG</button><button class="menu-btn menu-btn--export" data-tooltip="PDF">PDF</button></div>'
    || '</header>'

    -- Workspace
    || '<div class="workspace" id="workspace">'

    -- Layers panel
    || '<aside class="layers-panel" x-show="!layersPanelCollapsed" x-transition>'
    || '<div class="panel-header"><span class="panel-title">Structure</span><span class="panel-count" x-text="elements.length"></span>'
    || '<button class="panel-collapse-btn" @click="toggleLayersPanel()"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 4l-4 4 4 4"/></svg></button></div>'
    || '<div class="panel-body" id="panelBodyLayers"><ul class="tree" id="tree">'
    || '<template x-for="el in elements" :key="el.id"><li @click.stop="selectElement(el.id, $event.metaKey || $event.ctrlKey)" :class="{active: selectedIds.includes(el.id)}" x-text="el.name || el.type" class="tree-item"></li></template>'
    || '</ul></div>'
    || '<div class="layers-actions">'
    || '<button class="action-btn" @click="deleteSelected()" :disabled="selectedIds.length===0" data-tooltip="Supprimer"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 4h10M6 4V3a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v1m2 0v9a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4h10z"/></svg></button>'
    || '<button class="action-btn" @click="duplicateSelected()" :disabled="selectedIds.length===0" data-tooltip="Dupliquer"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="5" width="8" height="8" rx="1"/><path d="M3 11V3a1 1 0 0 1 1-1h8"/></svg></button>'
    || '</div></aside>'

    -- Resize handle + Canvas
    || '<div class="resize-handle-v" id="resizeHandleL"></div>'
    || '<main class="canvas-viewport" id="canvasViewport"><div class="svg-wrap"><svg id="canvas"></svg></div></main>'
    || '<div class="resize-handle-v" id="resizeHandleR"></div>'

    -- Props panel
    || '<aside class="properties-panel" x-show="!propsPanelCollapsed" x-transition>'
    || '<div class="panel-header"><span class="panel-title" x-text="selectedElement ? (selectedElement.name || selectedElement.type) : ''Proprietes''"></span>'
    || '<button class="panel-collapse-btn" @click="togglePropsPanel()"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 4l4 4-4 4"/></svg></button></div>'
    || '<div class="panel-body" id="propsContent">'
    || '<template x-if="selectedElement">'
    || '<div class="props-form">'
    || '<label>X <input type="number" :value="selectedElement.x" @change="updateElement(selectedElement.id, {x: +$event.target.value})" class="prop-input"></label>'
    || '<label>Y <input type="number" :value="selectedElement.y" @change="updateElement(selectedElement.id, {y: +$event.target.value})" class="prop-input"></label>'
    || '<label>W <input type="number" :value="selectedElement.width" @change="updateElement(selectedElement.id, {width: +$event.target.value})" class="prop-input"></label>'
    || '<label>H <input type="number" :value="selectedElement.height" @change="updateElement(selectedElement.id, {height: +$event.target.value})" class="prop-input"></label>'
    || '<label>Fill <input type="color" :value="selectedElement.fill || ''#000000''" @input="updateElement(selectedElement.id, {fill: $event.target.value})" class="prop-color"></label>'
    || '<label>Opacity <input type="range" min="0" max="1" step="0.05" :value="selectedElement.opacity" @input="updateElement(selectedElement.id, {opacity: +$event.target.value})" class="prop-range"></label>'
    || '</div>'
    || '</template>'
    || '<template x-if="!selectedElement"><p class="props-empty">Selectionnez un element</p></template>'
    || '</div></aside>'

    || '</div>'

    -- Photo library
    || '<div class="resize-handle-h" id="resizeHandleH"></div>'
    || '<div class="photo-library" x-show="!photoCollapsed">'
    || '<div class="photo-header"><button class="photo-collapse-btn" @click="togglePhotoPanel()"><svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M2.5 4l3.5 3.5L9.5 4"/></svg></button><span class="photo-title">Bibliotheque</span><span class="photo-count" x-text="assets.length"></span></div>'
    || '<div class="photo-strip" id="photoGrid">'
    || '<template x-for="a in assets" :key="a.id"><div class="photo-thumb" @click="/* TODO: insert asset */" :title="a.filename"><img :src="a.thumb_path || a.path" :alt="a.filename"></div></template>'
    || '</div></div>'

    -- Toast
    || '<div x-show="toast" x-transition.opacity class="toast" :class="''toast-'' + (toast?.level || ''info'')" x-text="toast?.text"></div>'

    -- Image editor modal (keep legacy IDs for now)
    || '<div class="ie-overlay" id="imageEditorOverlay"><div class="ie-card"><div class="ie-header"><span class="ie-header-title">Modifier l''image</span><span class="ie-header-path"></span><button class="ie-close">&times;</button></div><div class="ie-body"><div class="ie-preview" id="iePreview"></div><div class="ie-controls" id="ieControls"></div></div><div class="ie-footer"><button class="ie-btn" id="ieCancel">Annuler</button><button class="ie-btn ie-btn-primary" id="ieApply">Appliquer</button></div></div></div>'

    || '</div>';
END;
$function$;
