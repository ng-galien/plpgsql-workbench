CREATE OR REPLACE FUNCTION pgv_qa.get_test_bad_uuid()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  EXECUTE 'SELECT $1::uuid' USING 'not-a-uuid';
  RETURN '';
END;
$function$;
