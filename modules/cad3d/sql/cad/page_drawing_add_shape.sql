CREATE OR REPLACE FUNCTION cad.page_drawing_add_shape(p_id integer, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_layer_id int := (p_body->>'layer_id')::int;
  v_type text := p_body->>'type';
  v_geometry jsonb;
  v_props jsonb;
  v_label text := nullif(trim(COALESCE(p_body->>'label', '')), '');
  v_shape_id int;
BEGIN
  IF v_layer_id IS NULL OR v_type IS NULL THEN
    RETURN '<template data-toast="error">Calque et type requis</template>';
  END IF;

  BEGIN
    v_geometry := COALESCE(p_body->>'geometry', '{}')::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN '<template data-toast="error">Géométrie JSON invalide</template>';
  END;

  BEGIN
    v_props := COALESCE(p_body->>'props', '{}')::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN '<template data-toast="error">Props JSON invalides</template>';
  END;

  v_shape_id := cad.add_shape(p_id, v_layer_id, v_type, v_geometry, v_props, v_label);

  RETURN format('<template data-toast="success">Shape #%s ajoutée</template>', v_shape_id)
    || format('<template data-redirect="/drawing/%s"></template>', p_id);
END;
$function$;
