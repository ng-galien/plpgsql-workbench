CREATE OR REPLACE FUNCTION crm.client_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client crm.client;
  v_contacts jsonb;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('crm.nav_clients')),
        pgv.ui_table('clients', jsonb_build_array(
          pgv.ui_col('name', pgv.t('crm.col_client'), pgv.ui_link('{name}', '/crm/client/{id}')),
          pgv.ui_col('type', pgv.t('crm.col_type')),
          pgv.ui_col('city', pgv.t('crm.col_city')),
          pgv.ui_col('tier', pgv.t('crm.col_tier'), pgv.ui_badge('{tier}')),
          pgv.ui_col('contact_count', pgv.t('crm.col_contacts')),
          pgv.ui_col('interaction_count', pgv.t('crm.col_interactions')),
          pgv.ui_col('active', pgv.t('crm.col_active'))
        ))
      ),
      'datasources', jsonb_build_object(
        'clients', pgv.ui_datasource('crm://client', 20, true, '-updated_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_client FROM crm.client WHERE id::text = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(ct) ORDER BY ct.is_primary DESC, ct.name), '[]'::jsonb)
    INTO v_contacts
    FROM crm.contact ct WHERE ct.client_id = v_client.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      -- Header
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('crm.nav_clients'), '/crm'),
        pgv.ui_heading(v_client.name)
      ),
      pgv.ui_row(
        pgv.ui_badge(crm.type_label(v_client.type)),
        pgv.ui_badge(upper(v_client.tier), crm.tier_variant(v_client.tier)),
        CASE WHEN v_client.active THEN pgv.ui_badge(pgv.t('crm.yes'), 'success') ELSE pgv.ui_badge(pgv.t('crm.no'), 'error') END
      ),

      -- Coordonnées
      pgv.ui_heading(pgv.t('crm.title_fiche'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('crm.field_email') || ': ' || COALESCE(v_client.email, '—')),
        pgv.ui_text(pgv.t('crm.field_phone') || ': ' || COALESCE(v_client.phone, '—'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('crm.field_address') || ': ' || COALESCE(v_client.address, '—')),
        pgv.ui_text(pgv.t('crm.field_city') || ': ' || COALESCE(v_client.city, '—')),
        pgv.ui_text(pgv.t('crm.field_postal_code') || ': ' || COALESCE(v_client.postal_code, '—'))
      ),
      pgv.ui_text(pgv.t('crm.field_notes') || ': ' || CASE WHEN v_client.notes = '' THEN '—' ELSE v_client.notes END),

      -- Contacts
      pgv.ui_heading(pgv.t('crm.title_contacts'), 3),
      pgv.ui_text(v_contacts::text)
    )
  );
END;
$function$;
