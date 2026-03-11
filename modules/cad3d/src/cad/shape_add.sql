CREATE OR REPLACE FUNCTION cad.shape_add(drawing_id integer, layer_id integer, type text, geometry text DEFAULT '{}'::text, props text DEFAULT '{}'::text, label text DEFAULT NULL::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_geometry jsonb;
  v_props jsonb;
  v_shape_id int;
BEGIN
  IF layer_id IS NULL OR type IS NULL THEN
    RETURN '<template data-toast="error">Calque et type requis</template>';
  END IF;

  BEGIN
    v_geometry := geometry::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN '<template data-toast="error">Géométrie JSON invalide</template>';
  END;

  BEGIN
    v_props := props::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN '<template data-toast="error">Props JSON invalides</template>';
  END;

  v_shape_id := cad.add_shape(drawing_id, layer_id, type, v_geometry, v_props, nullif(trim(COALESCE(label, '')), ''));

  RETURN format('<template data-toast="success">Shape #%s ajoutée</template>', v_shape_id)
    || format('<template data-redirect="/drawing?p_id=%s"></template>', drawing_id);
END;
$function$;
