CREATE OR REPLACE FUNCTION pgv_ut.test_select_search()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- Basic rendering
  v_html := pgv.select_search('p_article', 'Article', 'catalog.article_options', 'Rechercher...');
  RETURN NEXT ok(v_html LIKE '%data-ss-rpc="catalog.article_options"%', 'data-ss-rpc attribute present');
  RETURN NEXT ok(v_html LIKE '%class="pgv-ss"%', 'pgv-ss container class');
  RETURN NEXT ok(v_html LIKE '%class="pgv-ss-input"%', 'pgv-ss-input class on text input');
  RETURN NEXT ok(v_html LIKE '%name="p_article"%', 'hidden input has correct name');
  RETURN NEXT ok(v_html LIKE '%placeholder="Rechercher..."%', 'placeholder set');
  RETURN NEXT ok(v_html LIKE '%autocomplete="off"%', 'autocomplete off');

  -- Pre-filled value
  v_html := pgv.select_search('p_item', 'Item', 'ns.fn', '', '42', 'Widget XL');
  RETURN NEXT ok(v_html LIKE '%value="42"%', 'hidden input pre-filled with value');
  RETURN NEXT ok(v_html LIKE '%value="Widget XL"%', 'text input pre-filled with display');

  -- XSS escaping
  v_html := pgv.select_search('x', '<script>', 'a.b">', '<">');
  RETURN NEXT ok(v_html NOT LIKE '%<script>%', 'label escaped');
  RETURN NEXT ok(v_html NOT LIKE '%a.b">%', 'rpc escaped');

  -- No value / no display
  v_html := pgv.select_search('p_id', 'Choose', 'x.y');
  RETURN NEXT ok(v_html NOT LIKE '%value="%', 'no value attributes when NULL');
  RETURN NEXT ok(v_html LIKE '%placeholder=""%', 'empty placeholder default');
END;
$function$;
