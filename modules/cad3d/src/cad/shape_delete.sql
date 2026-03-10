CREATE OR REPLACE FUNCTION cad.shape_delete(shape_id integer, drawing_id integer)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF shape_id IS NULL THEN
    RETURN '<template data-toast="error">shape_id requis</template>';
  END IF;

  PERFORM cad.delete_shape(shape_id);

  RETURN format('<template data-toast="success">Shape #%s supprimée</template>', shape_id)
    || format('<template data-redirect="/drawing/%s"></template>', drawing_id);
END;
$function$;
