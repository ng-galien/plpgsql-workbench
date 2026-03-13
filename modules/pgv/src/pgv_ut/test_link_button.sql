CREATE OR REPLACE FUNCTION pgv_ut.test_link_button()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- 1. Basic link button (primary)
  v := pgv.link_button('/clients', 'Clients');
  RETURN NEXT ok(v LIKE '%<a href%', 'has anchor tag');
  RETURN NEXT ok(v LIKE '%role="button"%', 'has role button');
  RETURN NEXT ok(v LIKE '%pgv-link-button%', 'has pgv-link-button class');
  RETURN NEXT ok(v LIKE '%>Clients</a>%', 'has label');

  -- 2. Outline variant
  v := pgv.link_button('/new', 'New', 'outline');
  RETURN NEXT ok(v LIKE '%outline%', 'outline class present');

  -- 3. Secondary variant
  v := pgv.link_button('/back', 'Back', 'secondary');
  RETURN NEXT ok(v LIKE '%secondary%', 'secondary class present');

  -- 4. Contrast variant
  v := pgv.link_button('/x', 'X', 'contrast');
  RETURN NEXT ok(v LIKE '%contrast%', 'contrast class present');

  -- 5. XSS safety
  v := pgv.link_button('/x" onclick="alert(1)', 'Test');
  RETURN NEXT ok(v LIKE '%&quot;%', 'href is escaped');

  -- 6. Label escaping
  v := pgv.link_button('/x', '<script>alert(1)</script>');
  RETURN NEXT ok(v LIKE '%&lt;script&gt;%', 'label is escaped');

  RETURN;
END;
$function$;
