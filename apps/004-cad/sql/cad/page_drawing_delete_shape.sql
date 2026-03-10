CREATE OR REPLACE FUNCTION cad.page_drawing_delete_shape(p_id integer, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_shape_id int := (p_body->>'shape_id')::int;
BEGIN
  IF v_shape_id IS NULL THEN
    RETURN '<template data-toast="error">shape_id requis</template>';
  END IF;

  PERFORM cad.delete_shape(v_shape_id);

  RETURN format('<template data-toast="success">Shape #%s supprimée</template>', v_shape_id)
    || format('<template data-redirect="/drawing/%s"></template>', p_id);
END;
$function$;
