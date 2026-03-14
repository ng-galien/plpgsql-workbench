CREATE OR REPLACE FUNCTION document_ut.test_current_user_id()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_uid text;
BEGIN
  -- Default (no app.user_id set): returns 'dev'
  PERFORM set_config('app.user_id', '', true);
  v_uid := document.current_user_id();
  RETURN NEXT is(v_uid, 'dev', 'default returns dev');

  -- With app.user_id set
  PERFORM set_config('app.user_id', 'test-user-42', true);
  v_uid := document.current_user_id();
  RETURN NEXT is(v_uid, 'test-user-42', 'returns app.user_id when set');

  -- Reset
  PERFORM set_config('app.user_id', '', true);
  v_uid := document.current_user_id();
  RETURN NEXT is(v_uid, 'dev', 'back to dev after reset');
END;
$function$;
