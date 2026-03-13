CREATE OR REPLACE FUNCTION crm.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text;
  v_type text;
  v_tier text;
  v_active text;
  v_total int;
  v_new_month int;
  v_interactions_week int;
  v_rows text[];
  v_body text;
  v_city text;
  r record;
BEGIN
  -- Extract filters
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_tier := NULLIF(trim(COALESCE(p_params->>'tier', '')), '');
  v_active := NULLIF(trim(COALESCE(p_params->>'active', '')), '');
  v_city := NULLIF(trim(COALESCE(p_params->>'city', '')), '');

  -- Stats (unfiltered)
  SELECT count(*)::int INTO v_total FROM crm.client;
  SELECT count(*)::int INTO v_new_month FROM crm.client WHERE created_at >= date_trunc('month', now());
  SELECT count(*)::int INTO v_interactions_week FROM crm.interaction WHERE created_at >= date_trunc('week', now());

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('crm.stat_total_clients'), v_total::text),
    pgv.stat(pgv.t('crm.stat_new_month'), v_new_month::text),
    pgv.stat(pgv.t('crm.stat_interactions_week'), v_interactions_week::text)
  ]);

  -- Search/filter form
  v_body := v_body
    || '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', pgv.t('crm.field_search_name_email'), v_q)
    || pgv.sel('type', pgv.t('crm.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('crm.type_individual'), 'value', 'individual'),
         jsonb_build_object('label', pgv.t('crm.type_company'), 'value', 'company')
       ), COALESCE(v_type, ''))
    || pgv.sel('tier', pgv.t('crm.field_tier'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.filter_all'), 'value', ''),
         jsonb_build_object('label', 'Standard', 'value', 'standard'),
         jsonb_build_object('label', 'Premium', 'value', 'premium'),
         jsonb_build_object('label', 'VIP', 'value', 'vip')
       ), COALESCE(v_tier, ''))
    || pgv.sel('active', pgv.t('crm.field_active'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('crm.yes'), 'value', 'true'),
         jsonb_build_object('label', pgv.t('crm.no'), 'value', 'false')
       ), COALESCE(v_active, ''))
    || pgv.input('city', 'text', pgv.t('crm.field_city'), v_city)
    || '</div>'
    || '<button type="submit" class="secondary">' || pgv.t('crm.btn_filter') || '</button>'
    || '</form>';

  -- Client list with filters
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.name, crm.type_label(c.type) AS type_label,
           c.city, c.tier, c.active,
           (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id) AS nb_interactions
      FROM crm.client c
     WHERE (v_q IS NULL OR c.name ILIKE '%' || v_q || '%' OR c.email ILIKE '%' || v_q || '%')
       AND (v_type IS NULL OR c.type = v_type)
       AND (v_tier IS NULL OR c.tier = v_tier)
       AND (v_active IS NULL OR c.active = (v_active = 'true'))
       AND (v_city IS NULL OR c.city ILIKE '%' || v_city || '%')
     ORDER BY c.updated_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_client', jsonb_build_object('p_id', r.id)), pgv.esc(r.name)),
      r.type_label,
      COALESCE(r.city, '—'),
      pgv.badge(upper(r.tier), crm.tier_variant(r.tier)),
      r.nb_interactions::text,
      CASE WHEN r.active THEN pgv.t('crm.yes') ELSE pgv.t('crm.no') END
    ];
  END LOOP;

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('crm.empty_no_client'), pgv.t('crm.empty_first_client'));
  ELSIF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('crm.empty_no_results'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('crm.col_client'), pgv.t('crm.col_type'), pgv.t('crm.col_city'), pgv.t('crm.col_tier'), pgv.t('crm.col_interactions'), pgv.t('crm.col_active')],
      v_rows,
      20
    );
  END IF;

  v_body := v_body || '<p>'
    || pgv.form_dialog('dlg-new-client', pgv.t('crm.title_new_client'),
         crm.client_form_fields(),
         'post_client_save', pgv.t('crm.btn_new_client'))
    || ' '
    || pgv.form_dialog('dlg-import', pgv.t('crm.btn_import_csv'),
         '<p>' || pgv.t('crm.import_intro') || '</p>'
         || '<p><code>nom ; email ; telephone ; adresse ; ville ; code_postal ; type</code></p>'
         || '<p><small>' || pgv.t('crm.import_help') || '</small></p>'
         || pgv.textarea('csv', pgv.t('crm.field_csv'), NULL),
         'post_import_csv', pgv.t('crm.btn_import_csv'), 'secondary')
    || '</p>';

  RETURN v_body;
END;
$function$;
