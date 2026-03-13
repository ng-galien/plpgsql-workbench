CREATE OR REPLACE FUNCTION pgv.form(p_rpc text, p_body text, p_submit text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<form data-rpc="' || pgv.esc(p_rpc) || '">'
    || p_body
    || '<button type="submit">' || pgv.esc(coalesce(p_submit, pgv.t('send'))) || '</button>'
    || '</form>';
END;
$function$;
