CREATE OR REPLACE FUNCTION pgv.breadcrumb(VARIADIC p_items text[])
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total int := array_length(p_items, 1);
  v_pairs int := v_total / 2;
  v_html text := '<nav class="pgv-breadcrumb" aria-label="breadcrumb"><ul>';
BEGIN
  -- Render label/href pairs as links
  FOR i IN 0..v_pairs-1 LOOP
    v_html := v_html || '<li><a href="' || p_items[i*2+2] || '">' || pgv.esc(p_items[i*2+1]) || '</a></li>';
  END LOOP;
  -- Odd count: last item is current page (text only)
  IF v_total % 2 = 1 THEN
    v_html := v_html || '<li>' || pgv.esc(p_items[v_total]) || '</li>';
  END IF;
  RETURN v_html || '</ul></nav>';
END;
$function$;
