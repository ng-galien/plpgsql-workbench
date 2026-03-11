CREATE OR REPLACE FUNCTION pgv.nav(p_brand text, p_items jsonb, p_current text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_item jsonb;
  v_href text;
  v_label text;
  v_burger boolean := coalesce((p_options->>'burger')::boolean, false);
BEGIN
  IF v_burger THEN
    v_html := '<nav class="container-fluid pgv-nav-burger" x-data="{ open: false }">';
  ELSE
    v_html := '<nav class="container-fluid">';
  END IF;

  -- Brand + burger toggle
  v_html := v_html || '<ul><li><a href="' || pgv.call_ref('get_index') || '" class="pgv-brand"><strong>' || pgv.esc(p_brand) || '</strong></a></li>';
  IF v_burger THEN
    v_html := v_html || '<li class="pgv-burger-li">'
      || '<button class="pgv-burger" @click="open = !open" aria-label="Menu">'
      || '<span x-text="open ? ''✕'' : ''☰''">☰</span></button></li>';
  END IF;
  v_html := v_html || '</ul>';

  -- Menu links
  IF v_burger THEN
    v_html := v_html || '<ul class="pgv-menu" :class="open && ''pgv-menu-open''" @click="open = false">';
  ELSE
    v_html := v_html || '<ul>';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_href  := v_item->>'href';
    v_label := v_item->>'label';
    IF v_href ~ '^https?://' THEN
      v_html := v_html || format('<li><a href="%s" target="_blank" rel="noopener">%s</a></li>', v_href, pgv.esc(v_label));
    ELSIF v_href = p_current THEN
      v_html := v_html || format('<li><a href="%s" aria-current="page">%s</a></li>', v_href, pgv.esc(v_label));
    ELSE
      v_html := v_html || format('<li><a href="%s">%s</a></li>', v_href, pgv.esc(v_label));
    END IF;
  END LOOP;
  v_html := v_html || '</ul>';

  -- Theme toggle
  v_html := v_html || '<ul><li>'
    || '<button class="pgv-theme-toggle" data-toggle-theme title="Changer de theme">'
    || '&#x263E;</button></li></ul></nav>';

  RETURN v_html;
END;
$function$;
