CREATE OR REPLACE FUNCTION crm.interaction_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_i crm.interaction;
  v_client_name text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('crm.nav_interactions')),
        pgv.ui_table('interactions', jsonb_build_array(
          pgv.ui_col('subject', pgv.t('crm.field_subject'), pgv.ui_link('{subject}', '/crm/interaction/{id}')),
          pgv.ui_col('type', pgv.t('crm.field_type'), pgv.ui_badge('{type}')),
          pgv.ui_col('client_name', pgv.t('crm.col_client'), pgv.ui_link('{client_name}', '/crm/client/{client_id}')),
          pgv.ui_col('created_at', pgv.t('crm.col_date'))
        ))
      ),
      'datasources', jsonb_build_object(
        'interactions', pgv.ui_datasource('crm://interaction', 20, true, '-created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_i FROM crm.interaction WHERE id::text = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT name INTO v_client_name FROM crm.client WHERE id = v_i.client_id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('crm.nav_interactions'), '/crm/interactions'),
        pgv.ui_heading(v_i.subject)
      ),
      pgv.ui_row(
        pgv.ui_badge(crm.type_label(v_i.type), CASE v_i.type WHEN 'call' THEN 'info' WHEN 'visit' THEN 'success' WHEN 'email' THEN 'warning' ELSE 'info' END),
        pgv.ui_link(v_client_name, '/crm/client/' || v_i.client_id)
      ),
      pgv.ui_text(CASE WHEN v_i.body = '' THEN '—' ELSE v_i.body END),
      pgv.ui_text(to_char(v_i.created_at, 'DD/MM/YYYY HH24:MI'))
    )
  );
END;
$function$;
