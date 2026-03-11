CREATE OR REPLACE FUNCTION cad.get_drawing(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_body text;
  v_shapes text;
  v_layers jsonb;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé', 'Le dessin #' || p_id || ' n''existe pas.');
  END IF;

  -- Layout: tree + canvas
  v_body := '<div class="cad-layout">'
    || cad.fragment_tree(p_id)
    || '<div>' || pgv.svg_canvas(cad.render_svg(p_id)) || '</div>'
    || '</div>';

  -- Stats
  v_body := v_body || pgv.grid(
    pgv.stat('Shapes', (SELECT count(*)::text FROM cad.shape WHERE drawing_id = p_id)),
    pgv.stat('Calques', (SELECT count(*)::text FROM cad.layer WHERE drawing_id = p_id)),
    pgv.stat('Échelle', '1:' || v_drawing.scale::text),
    pgv.stat('Taille', v_drawing.width || ' × ' || v_drawing.height || ' ' || v_drawing.unit)
  );

  -- Liste des shapes
  SELECT string_agg(line, E'\n' ORDER BY sid) INTO v_shapes
  FROM (
    SELECT s.id AS sid,
      format('| %s | %s | %s | %s | %s |',
        s.id, s.type,
        COALESCE(s.label, '-'),
        l.name,
        pgv.action('shape_delete', 'Suppr.',
          jsonb_build_object('shape_id', s.id, 'drawing_id', p_id),
          'Supprimer cette shape ?', 'danger')
      ) AS line
    FROM cad.shape s
    JOIN cad.layer l ON l.id = s.layer_id
    WHERE s.drawing_id = p_id
  ) sub;

  IF v_shapes IS NOT NULL THEN
    v_body := v_body || '<md>' || E'\n'
      || '| ID | Type | Label | Calque | Action |' || E'\n'
      || '|----|------|-------|--------|--------|' || E'\n'
      || v_shapes || E'\n'
      || '</md>';
  END IF;

  -- Options calques en jsonb pour pgv.sel
  SELECT jsonb_agg(jsonb_build_object('value', l.id::text, 'label', l.name) ORDER BY l.sort_order)
  INTO v_layers
  FROM cad.layer l WHERE l.drawing_id = p_id;

  -- Formulaire ajout shape via RPC dédié
  v_body := v_body || '<details><summary>Ajouter une shape</summary>'
    || '<form data-rpc="shape_add">'
    || format('<input type="hidden" name="drawing_id" value="%s">', p_id)
    || '<div class="grid">'
    || pgv.sel('layer_id', 'Calque', COALESCE(v_layers, '[]'::jsonb))
    || pgv.sel('type', 'Type', '[
        {"value":"line","label":"Ligne"},
        {"value":"rect","label":"Rectangle"},
        {"value":"circle","label":"Cercle"},
        {"value":"text","label":"Texte"},
        {"value":"dimension","label":"Cote"}
      ]'::jsonb)
    || '</div>'
    || pgv.input('label', 'text', 'Label (optionnel)')
    || '<details><summary>Géométrie (JSON)</summary>'
    || pgv.textarea('geometry', 'Géométrie JSON', '{"x1":0,"y1":0,"x2":100,"y2":0}')
    || '</details>'
    || '<details><summary>Propriétés bois (JSON)</summary>'
    || pgv.textarea('props', 'Props JSON', '{}')
    || '</details>'
    || '<button type="submit">Ajouter</button>'
    || '</form></details>';

  -- Liens
  v_body := v_body || '<p>'
    || '<a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', p_id)) || '">Vue 3D</a>'
    || ' | '
    || '<a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', p_id)) || '">Liste de débit</a>'
    || '</p>';

  RETURN v_body;
END;
$function$;
