CREATE OR REPLACE FUNCTION pgv_ut.test_search()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_item text;
  v_html text;
BEGIN
  -- search_item renders correctly
  v_item := pgv.search_item(ROW('/test?id=1', '📄', 'document', 'Mon doc', 'Detail ici', 0.9)::pgv.search_result);
  RETURN NEXT ok(v_item LIKE '%pgv-search-item%', 'search_item has pgv-search-item class');
  RETURN NEXT ok(v_item LIKE '%data-href="/test?id=1"%', 'search_item has data-href');
  RETURN NEXT ok(v_item LIKE '%pgv-search-icon%', 'search_item has icon');
  RETURN NEXT ok(v_item LIKE '%<strong>Mon doc</strong>%', 'search_item has label');
  RETURN NEXT ok(v_item LIKE '%pgv-badge%', 'search_item has kind badge');
  RETURN NEXT ok(v_item LIKE '%<small>Detail ici</small>%', 'search_item has detail');

  -- search_item escapes label
  v_item := pgv.search_item(ROW('/x', NULL, NULL, '<script>xss</script>', NULL, 0.5)::pgv.search_result);
  RETURN NEXT ok(v_item NOT LIKE '%<script>%', 'search_item escapes label');

  -- search_item without optional fields
  v_item := pgv.search_item(ROW('/x', NULL, NULL, 'Simple', NULL, 0.5)::pgv.search_result);
  RETURN NEXT ok(v_item NOT LIKE '%pgv-search-icon%', 'search_item without icon omits icon span');
  RETURN NEXT ok(v_item NOT LIKE '%pgv-badge%', 'search_item without kind omits badge');
  RETURN NEXT ok(v_item NOT LIKE '%<small>%', 'search_item without detail omits small');

  -- search dispatcher finds pgv_qa.search()
  v_html := pgv.search('doc', 'pgv_qa');
  RETURN NEXT ok(v_html LIKE '%pgv-search-results%', 'search returns results list');
  RETURN NEXT ok(v_html LIKE '%Premier document%', 'search finds matching item');

  -- search with no matches
  v_html := pgv.search('zzzznotfound', 'pgv_qa');
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'search no match returns empty state');

  -- search on schema without search() function
  v_html := pgv.search('test', 'pgv_ut');
  RETURN NEXT ok(v_html LIKE '%non disponible%', 'search on schema without provider returns message');
END;
$function$;
