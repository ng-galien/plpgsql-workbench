CREATE OR REPLACE FUNCTION crm.get_interactions(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text;
  v_type text;
  v_period text;
  v_total int;
  v_tl jsonb;
  v_body text;
  v_date_from timestamptz;
  r record;
BEGIN
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_period := NULLIF(trim(COALESCE(p_params->>'period', '')), '');

  -- Period filter
  IF v_period = 'week' THEN
    v_date_from := date_trunc('week', now());
  ELSIF v_period = 'month' THEN
    v_date_from := date_trunc('month', now());
  ELSIF v_period = '3months' THEN
    v_date_from := now() - interval '3 months';
  END IF;

  SELECT count(*)::int INTO v_total FROM crm.interaction;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('crm.stat_total_interactions'), v_total::text)
  ]);

  -- Filters
  v_body := v_body
    || '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', pgv.t('crm.field_search_subject'), v_q)
    || pgv.sel('type', pgv.t('crm.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('crm.type_call'), 'value', 'call'),
         jsonb_build_object('label', pgv.t('crm.type_visit'), 'value', 'visit'),
         jsonb_build_object('label', pgv.t('crm.type_email'), 'value', 'email'),
         jsonb_build_object('label', pgv.t('crm.type_note'), 'value', 'note')
       ), COALESCE(v_type, ''))
    || pgv.sel('period', pgv.t('crm.field_period'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.filter_all_f'), 'value', ''),
         jsonb_build_object('label', pgv.t('crm.period_week'), 'value', 'week'),
         jsonb_build_object('label', pgv.t('crm.period_month'), 'value', 'month'),
         jsonb_build_object('label', pgv.t('crm.period_3months'), 'value', '3months')
       ), COALESCE(v_period, ''))
    || '</div>'
    || '<button type="submit" class="secondary">' || pgv.t('crm.btn_filter') || '</button>'
    || '</form>';

  v_tl := '[]'::jsonb;
  FOR r IN
    SELECT i.type, i.subject, i.created_at, c.name AS client_name
      FROM crm.interaction i
      JOIN crm.client c ON c.id = i.client_id
     WHERE (v_q IS NULL OR i.subject ILIKE '%' || v_q || '%')
       AND (v_type IS NULL OR i.type = v_type)
       AND (v_date_from IS NULL OR i.created_at >= v_date_from)
     ORDER BY i.created_at DESC
  LOOP
    v_tl := v_tl || jsonb_build_object(
      'date', to_char(r.created_at, 'DD/MM/YYYY HH24:MI'),
      'label', crm.type_label(r.type) || E' \u2014 ' || r.subject,
      'detail', r.client_name,
      'badge', CASE r.type WHEN 'call' THEN 'primary' WHEN 'visit' THEN 'success' ELSE 'info' END
    );
  END LOOP;

  IF jsonb_array_length(v_tl) = 0 AND v_total = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('crm.empty_no_interaction'));
  ELSIF jsonb_array_length(v_tl) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('crm.empty_no_results'));
  ELSE
    v_body := v_body || pgv.timeline(v_tl);
  END IF;

  RETURN v_body;
END;
$function$;
