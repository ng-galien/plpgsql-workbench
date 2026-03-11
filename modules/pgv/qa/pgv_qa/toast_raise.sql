CREATE OR REPLACE FUNCTION pgv_qa.toast_raise()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'Document introuvable dans la base'
    USING HINT = 'Verifiez que le document a bien ete indexe.';
END;
$function$;
