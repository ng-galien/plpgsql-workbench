CREATE OR REPLACE FUNCTION pgv.filter_form(p_body text, p_submit text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<form data-filter>'
    || '<div class="grid">'
    || p_body
    || '</div>'
    || '<button type="submit" class="secondary">'
    || pgv.esc(coalesce(p_submit, pgv.t('pgv.filter')))
    || '</button>'
    || '</form>';
END;
$function$;
