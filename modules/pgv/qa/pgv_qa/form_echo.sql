CREATE OR REPLACE FUNCTION pgv_qa.form_echo(p_name text DEFAULT ''::text, p_email text DEFAULT ''::text, p_role text DEFAULT ''::text, p_notes text DEFAULT ''::text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '<template data-toast="success">Formulaire recu: ' || pgv.esc(p_name) || '</template>'
      || '<template data-redirect="/forms"></template>';
END;
$function$;
