CREATE OR REPLACE FUNCTION pgv.accordion(VARIADIC p_items text[])
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_count int := array_length(p_items, 1) / 2;
  v_html text := '';
BEGIN
  FOR i IN 0..v_count-1 LOOP
    v_html := v_html || '<details class="pgv-accordion">'
      || '<summary>' || pgv.esc(p_items[i*2+1]) || '</summary>'
      || '<div>' || p_items[i*2+2] || '</div>'
      || '</details>';
  END LOOP;
  RETURN v_html;
END;
$function$;
