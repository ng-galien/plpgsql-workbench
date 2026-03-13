CREATE OR REPLACE FUNCTION document.get_company(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c    document.company;
  v_body text;
BEGIN
  v_c := document.company_info();

  IF v_c.id IS NULL THEN
    v_body := pgv.empty(pgv.t('document.title_company_empty'), pgv.t('document.title_company_help'));
  ELSE
    v_body := pgv.grid(VARIADIC ARRAY[
      pgv.card(pgv.t('document.field_name'), pgv.esc(v_c.name)),
      pgv.card(pgv.t('document.field_siret'), COALESCE(pgv.esc(v_c.siret), '—')),
      pgv.card(pgv.t('document.field_tva_intra'), COALESCE(pgv.esc(v_c.tva_intra), '—'))
    ]);
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      pgv.card(pgv.t('document.field_address'), COALESCE(pgv.esc(v_c.address), '—')),
      pgv.card(pgv.t('document.field_city'), COALESCE(pgv.esc(v_c.city), '—')),
      pgv.card(pgv.t('document.field_postal_code'), COALESCE(pgv.esc(v_c.postal_code), '—'))
    ]);
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      pgv.card(pgv.t('document.field_phone'), COALESCE(pgv.esc(v_c.phone), '—')),
      pgv.card(pgv.t('document.field_email'), COALESCE(pgv.esc(v_c.email), '—')),
      pgv.card(pgv.t('document.field_website'), COALESCE(pgv.esc(v_c.website), '—'))
    ]);
    IF v_c.mentions IS NOT NULL THEN
      v_body := v_body || '<blockquote>' || pgv.esc(v_c.mentions) || '</blockquote>';
    END IF;
  END IF;

  -- Edit form
  v_body := COALESCE(v_body, '') || '<h3>' || pgv.t('document.title_company') || '</h3>'
    || '<form data-rpc="post_company_save">'
    || pgv.input('p_name', 'text', pgv.t('document.field_name'), v_c.name)
    || '<div class="grid">'
    || pgv.input('p_siret', 'text', pgv.t('document.field_siret'), v_c.siret)
    || pgv.input('p_tva_intra', 'text', pgv.t('document.field_tva_intra'), v_c.tva_intra)
    || '</div>'
    || pgv.input('p_address', 'text', pgv.t('document.field_address'), v_c.address)
    || '<div class="grid">'
    || pgv.input('p_city', 'text', pgv.t('document.field_city'), v_c.city)
    || pgv.input('p_postal_code', 'text', pgv.t('document.field_postal_code'), v_c.postal_code)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('p_phone', 'text', pgv.t('document.field_phone'), v_c.phone)
    || pgv.input('p_email', 'email', pgv.t('document.field_email'), v_c.email)
    || pgv.input('p_website', 'text', pgv.t('document.field_website'), v_c.website)
    || '</div>'
    || pgv.textarea('p_mentions', pgv.t('document.field_mentions'), v_c.mentions)
    || '<button type="submit">' || pgv.t('document.btn_save') || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
