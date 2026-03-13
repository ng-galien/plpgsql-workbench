CREATE OR REPLACE FUNCTION pgv_ut.test_doc()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  -- Existing topic
  v := pgv.doc('testing');
  RETURN NEXT ok(v ~ '<md>', 'wraps in md tag');
  RETURN NEXT ok(v ~ 'pgTAP', 'contains topic content');
  RETURN NEXT ok(v ~ '</md>', 'closes md tag');

  -- Missing topic
  v := pgv.doc('nonexistent_topic_xyz');
  RETURN NEXT ok(v ~ 'pgv-empty', 'missing topic returns empty state');
  RETURN NEXT ok(v ~ 'nonexistent_topic_xyz', 'shows topic name in empty');
END;
$function$;
