CREATE OR REPLACE FUNCTION document.post_canvas_delete(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM document.canvas
  WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Canvas introuvable</template>';
  END IF;

  RETURN '<template data-toast="success">Canvas supprimé</template>'
      || '<template data-redirect="/"></template>';
END;
$function$;
