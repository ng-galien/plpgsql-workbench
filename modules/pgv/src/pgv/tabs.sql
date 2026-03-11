CREATE OR REPLACE FUNCTION pgv.tabs(VARIADIC p_items text[])
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_count int := array_length(p_items, 1) / 2;
  v_nav text := '';
  v_panels text := '';
BEGIN
  FOR i IN 0..v_count-1 LOOP
    v_nav := v_nav || '<button @click="tab=' || i || '" :class="tab===' || i || ' && ''active''">'
      || pgv.esc(p_items[i*2+1]) || '</button>';
    v_panels := v_panels || '<div x-show="tab===' || i || '">' || p_items[i*2+2] || '</div>';
  END LOOP;
  RETURN '<div class="pgv-tabs" x-data="{tab:0}">'
    || '<nav class="pgv-tabs-nav">' || v_nav || '</nav>'
    || v_panels || '</div>';
END;
$function$;
