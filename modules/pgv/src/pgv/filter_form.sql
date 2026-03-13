CREATE OR REPLACE FUNCTION pgv.filter_form(p_body text, p_submit text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<div class="pgv-filter">'
    || '<form data-filter class="pgv-filter-bar">'
    || '<div class="pgv-filter-inputs">'
    || p_body
    || '</div>'
    || '<button type="submit" class="pgv-filter-submit">'
    || pgv.esc(coalesce(p_submit, pgv.t('pgv.filter')))
    || '</button>'
    || '</form>'
    || '<div class="pgv-filter-chips"></div>'
    || '</div>';
END;
$function$;
