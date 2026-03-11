CREATE OR REPLACE FUNCTION cad_qa.get_drawing(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_body text;
  v_shapes text;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé', 'Le dessin #' || p_id || ' n''existe pas.');
  END IF;

  -- Navigation
  v_body := '<p>'
    || '<strong>Vue 2D</strong>'
    || ' | <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', p_id)) || '">Vue 3D</a>'
    || ' | <a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', p_id)) || '">Liste de débit</a>'
    || '</p>';

  -- Layout: tree + canvas
  v_body := v_body || '<div class="cad-layout">'
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
      format('| %s | %s | %s | %s |',
        s.id, s.type,
        COALESCE(s.label, '-'),
        l.name
      ) AS line
    FROM cad.shape s
    JOIN cad.layer l ON l.id = s.layer_id
    WHERE s.drawing_id = p_id
  ) sub;

  IF v_shapes IS NOT NULL THEN
    v_body := v_body || '<md>' || E'\n'
      || '| ID | Type | Label | Calque |' || E'\n'
      || '|----|------|-------|--------|' || E'\n'
      || v_shapes || E'\n'
      || '</md>';
  END IF;

  RETURN v_body;
END;
$function$;
