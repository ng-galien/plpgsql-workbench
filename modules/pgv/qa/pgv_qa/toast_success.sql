CREATE OR REPLACE FUNCTION pgv_qa.toast_success()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '<template data-toast="success">Operation reussie</template>';
END;
$function$;
