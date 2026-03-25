CREATE OR REPLACE FUNCTION catalog.get_article(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art catalog.article;
  v_category_name text;
  v_unit_label text;
  v_body text;
BEGIN
  SELECT * INTO v_art FROM catalog.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('catalog.err_not_found')); END IF;

  SELECT c.name INTO v_category_name FROM catalog.category c WHERE c.id = v_art.category_id;
  SELECT u.label INTO v_unit_label FROM catalog.unit u WHERE u.code = v_art.unit;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('catalog.field_sale_price'),
      CASE WHEN v_art.sale_price IS NOT NULL
        THEN to_char(v_art.sale_price, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat(pgv.t('catalog.field_purchase_price'),
      CASE WHEN v_art.purchase_price IS NOT NULL
        THEN to_char(v_art.purchase_price, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat(pgv.t('catalog.field_vat_rate'), v_art.vat_rate || '%'),
    pgv.stat(pgv.t('catalog.field_unit'), coalesce(v_unit_label, v_art.unit))
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    pgv.t('catalog.field_reference'), coalesce(pgv.esc(v_art.reference), '—'),
    pgv.t('catalog.field_name'), pgv.esc(v_art.name),
    pgv.t('catalog.field_category'), coalesce(pgv.badge(v_category_name), '—'),
    pgv.t('catalog.field_description'), coalesce(pgv.esc(v_art.description), '—'),
    pgv.t('catalog.field_status'), CASE WHEN v_art.active THEN pgv.badge(pgv.t('catalog.badge_active'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactive'), 'warning') END,
    pgv.t('catalog.detail_created_at'), to_char(v_art.created_at, 'DD/MM/YYYY HH24:MI'),
    pgv.t('catalog.detail_updated_at'), to_char(v_art.updated_at, 'DD/MM/YYYY HH24:MI')
  ]);

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">%s</a> ',
       pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id)),
       pgv.t('catalog.btn_edit'))
    || CASE WHEN v_art.active
       THEN pgv.action('post_article_update',
              pgv.t('catalog.action_deactivate'),
              jsonb_build_object('id', p_id, 'active', 'false'),
              pgv.t('catalog.confirm_deactivate'), 'danger')
       ELSE pgv.action('post_article_update',
              pgv.t('catalog.action_activate'),
              jsonb_build_object('id', p_id, 'active', 'true'))
       END
    || '</p>';

  RETURN v_body;
END;
$function$;
