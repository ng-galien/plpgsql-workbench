CREATE OR REPLACE FUNCTION pgv.throw_not_found(p_detail text DEFAULT 'Not found'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'Not Found', DETAIL = p_detail;
END; $function$;
