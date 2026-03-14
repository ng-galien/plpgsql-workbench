CREATE OR REPLACE FUNCTION document.post_canvas_duplicate(p_source_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src document.canvas;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_src FROM document.canvas WHERE id = p_source_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_src IS NULL THEN
    RETURN '<template data-toast="error">Canvas introuvable</template>';
  END IF;

  v_new_id := document.canvas_duplicate(p_source_id, v_src.name || ' (copie)');

  RETURN '<template data-toast="success">Canvas dupliqué</template>'
      || '<template data-redirect="' || pgv.call_ref('get_canvas', jsonb_build_object('p_id', v_new_id)) || '"></template>';
END;
$function$;
