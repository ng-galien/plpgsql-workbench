CREATE OR REPLACE FUNCTION pgv_qa.toast_error()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '<template data-toast="error">Echec de l''operation</template>';
END;
$function$;
