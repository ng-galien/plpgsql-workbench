CREATE OR REPLACE FUNCTION cad_qa.get_drawing(p_id integer)
 RETURNS "text/html"
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_body text;
  v_shapes text;
BEGIN
  -- Default to first drawing when no id provided
  IF p_id IS NULL THEN
    SELECT id INTO p_id FROM cad.drawing ORDER BY name LIMIT 1;
    IF p_id IS NULL THEN
      RETURN pgv.empty('Aucun dessin', 'Lancez le seed pour créer des données.');
    END IF;
  END IF;

  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé', 'Le dessin #' || p_id || ' n''existe pas.');
  END IF;

  v_body := cad.fragment_drawing_nav(p_id, 'Vue 2D');

  -- Layout: tree + canvas
  v_body := v_body || '<section><div class="cad-layout">'
    || cad.fragment_tree(p_id)
    || '<div>' || pgv.svg_canvas(cad.render_svg(p_id)) || '</div>'
    || '</div></section>';

  -- Stats
  v_body := v_body || '<section>' || pgv.grid(
    pgv.stat('Shapes', (SELECT count(*)::text FROM cad.shape WHERE drawing_id = p_id)),
    pgv.stat('Calques', (SELECT count(*)::text FROM cad.layer WHERE drawing_id = p_id)),
    pgv.stat('Échelle', '1:' || v_drawing.scale::text),
    pgv.stat('Taille', v_drawing.width || ' × ' || v_drawing.height || ' ' || v_drawing.unit)
  ) || '</section>';

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
    v_body := v_body || '<section><md>' || E'\n'
      || '| ID | Type | Label | Calque |' || E'\n'
      || '|----|------|-------|--------|' || E'\n'
      || v_shapes || E'\n'
      || '</md></section>';
  END IF;

  RETURN v_body;
END;
$function$;
