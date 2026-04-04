CREATE OR REPLACE FUNCTION pgv.throw_invalid(p_detail text DEFAULT 'Bad request'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = p_detail;
END; $function$;
