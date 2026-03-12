CREATE OR REPLACE FUNCTION pgv.workflow(p_steps jsonb, p_current text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '<div class="pgv-wf">';
  v_step jsonb;
  v_key text;
  v_label text;
  v_found boolean := false;
  v_cls text;
  v_i int := 0;
  v_total int;
BEGIN
  v_total := jsonb_array_length(p_steps);
  FOR v_step IN SELECT * FROM jsonb_array_elements(p_steps) LOOP
    v_key := v_step->>'key';
    v_label := coalesce(v_step->>'label', v_key);
    v_i := v_i + 1;

    IF v_key = p_current THEN
      v_cls := 'pgv-wf-step pgv-wf-current';
      v_found := true;
    ELSIF NOT v_found THEN
      v_cls := 'pgv-wf-step pgv-wf-done';
    ELSE
      v_cls := 'pgv-wf-step pgv-wf-future';
    END IF;

    v_html := v_html || '<div class="' || v_cls || '">'
      || '<span class="pgv-wf-dot"></span>'
      || '<span class="pgv-wf-label">' || pgv.esc(v_label) || '</span>'
      || '</div>';

    IF v_i < v_total THEN
      v_html := v_html || '<div class="pgv-wf-line' 
        || CASE WHEN NOT v_found THEN ' pgv-wf-line-done' ELSE '' END
        || '"></div>';
    END IF;
  END LOOP;

  RETURN v_html || '</div>';
END;
$function$;
