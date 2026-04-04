CREATE OR REPLACE FUNCTION pgv_ut.test_avatar()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(pgv.avatar('Jean Dupont') LIKE '%pgv-avatar%', 'avatar has pgv-avatar class');
  RETURN NEXT ok(pgv.avatar('Jean Dupont') LIKE '%JD%', 'avatar extracts initials JD');
  RETURN NEXT ok(pgv.avatar('Alice') LIKE '%A%', 'single name takes first char');
  RETURN NEXT ok(pgv.avatar('Marie Claire Durand') LIKE '%MC%', 'three names takes first two words');
  RETURN NEXT ok(pgv.avatar('<script>') NOT LIKE '%<script>%', 'avatar escapes name');
END;
$function$;
