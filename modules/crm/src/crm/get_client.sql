CREATE OR REPLACE FUNCTION crm.get_client(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client crm.client;
  v_fiche text;
  v_contacts text;
  v_interactions text;
  v_tab_fiche text;
  v_tab_interactions text;
  v_body text;
  r record;
  v_activity text;
  v_rows text;
  v_timeline jsonb;
  v_stats text;
  v_n int;
  v_ca numeric;
BEGIN
  SELECT * INTO v_client FROM crm.client WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.alert(pgv.t('crm.err_not_found'), 'danger');
  END IF;

  v_fiche := pgv.dl(VARIADIC ARRAY[
    pgv.t('crm.field_type'), crm.type_label(v_client.type),
    pgv.t('crm.field_email'), COALESCE(v_client.email, '—'),
    pgv.t('crm.field_phone'), COALESCE(v_client.phone, '—'),
    pgv.t('crm.field_address'), COALESCE(v_client.address, '—'),
    pgv.t('crm.field_city'), COALESCE(v_client.city, '—'),
    pgv.t('crm.field_postal_code'), COALESCE(v_client.postal_code, '—'),
    pgv.t('crm.field_tier'), pgv.badge(upper(v_client.tier), crm.tier_variant(v_client.tier)),
    pgv.t('crm.field_active'), CASE WHEN v_client.active THEN pgv.t('crm.yes') ELSE pgv.t('crm.no') END,
    pgv.t('crm.field_notes'), CASE WHEN v_client.notes = '' THEN '—' ELSE pgv.esc(v_client.notes) END
  ]);

  IF array_length(v_client.tags, 1) > 0 THEN
    v_fiche := v_fiche || '<p>';
    FOR i IN 1..array_length(v_client.tags, 1) LOOP
      v_fiche := v_fiche || pgv.badge(v_client.tags[i], 'default') || ' ';
    END LOOP;
    v_fiche := v_fiche || '</p>';
  END IF;

  v_contacts := '';
  FOR r IN SELECT * FROM crm.contact WHERE client_id = p_id ORDER BY is_primary DESC, name LOOP
    v_contacts := v_contacts || pgv.card(
      pgv.esc(r.name) || CASE WHEN r.is_primary THEN ' ' || pgv.badge(pgv.t('crm.badge_primary'), 'primary') ELSE '' END,
      pgv.dl(VARIADIC ARRAY[
        pgv.t('crm.field_role'), CASE WHEN r.role = '' THEN '—' ELSE pgv.esc(r.role) END,
        pgv.t('crm.field_email'), COALESCE(r.email, '—'),
        pgv.t('crm.field_phone'), COALESCE(r.phone, '—')
      ]),
      pgv.action('post_contact_delete', pgv.t('crm.btn_delete'), jsonb_build_object('id', r.id), pgv.t('crm.confirm_delete_contact'), 'danger')
    );
  END LOOP;

  IF v_contacts = '' THEN
    v_contacts := pgv.empty(pgv.t('crm.empty_no_contacts'));
  END IF;

  v_contacts := v_contacts || pgv.accordion(VARIADIC ARRAY[
    pgv.t('crm.title_add_contact'),
    pgv.form('post_contact_add',
      '<input type="hidden" name="client_id" value="' || p_id || '">'
      || pgv.input('name', 'text', pgv.t('crm.field_name'), NULL, true)
      || pgv.input('role', 'text', pgv.t('crm.field_role'))
      || pgv.input('email', 'email', pgv.t('crm.field_email'))
      || pgv.input('phone', 'tel', pgv.t('crm.field_phone'))
      || pgv.checkbox('is_primary', pgv.t('crm.label_primary_contact')),
      pgv.t('crm.btn_add'))
  ]);

  v_tab_fiche := v_fiche || '<hr>' || '<h4>' || pgv.t('crm.title_contacts') || '</h4>' || v_contacts;

  -- Activité liée (cross-module)
  v_activity := '';
  v_stats := '';

  BEGIN
    EXECUTE 'SELECT count(*) FROM quote.devis WHERE client_id = $1' INTO v_n USING p_id;
    IF v_n > 0 THEN v_stats := v_stats || pgv.stat(pgv.t('crm.cross_quotes'), v_n::text); END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    EXECUTE '
      SELECT count(DISTINCT f.id),
             coalesce(sum(l.quantite * l.prix_unitaire * (1 + l.tva_rate / 100)), 0)
      FROM quote.facture f
      LEFT JOIN quote.ligne l ON l.facture_id = f.id
      WHERE f.client_id = $1'
    INTO v_n, v_ca USING p_id;
    IF v_n > 0 THEN
      v_stats := v_stats || pgv.stat(pgv.t('crm.cross_invoices'), v_n::text);
      v_stats := v_stats || pgv.stat(pgv.t('crm.cross_revenue'), to_char(v_ca, 'FM999G999G990D00') || E' \u20ac');
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    EXECUTE 'SELECT count(*) FROM project.chantier WHERE client_id = $1' INTO v_n USING p_id;
    IF v_n > 0 THEN v_stats := v_stats || pgv.stat(pgv.t('crm.cross_projects'), v_n::text); END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF v_stats <> '' THEN
    v_activity := pgv.grid(v_stats) || v_activity;
  END IF;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM quote.devis WHERE client_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [' || pgv.t('crm.cross_see') || '](/' || 'quote/devis?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>' || pgv.t('crm.cross_quotes') || '</h4><md>' || E'\n' || '| ' || pgv.t('crm.col_number') || ' | ' || pgv.t('crm.col_status') || ' | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM project.chantier WHERE client_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [' || pgv.t('crm.cross_see') || '](/' || 'project/chantier?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>' || pgv.t('crm.cross_projects') || '</h4><md>' || E'\n' || '| ' || pgv.t('crm.col_number') || ' | ' || pgv.t('crm.col_status') || ' | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM purchase.commande WHERE fournisseur_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [' || pgv.t('crm.cross_see') || '](/' || 'purchase/commande?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>' || pgv.t('crm.cross_purchase_orders') || '</h4><md>' || E'\n' || '| ' || pgv.t('crm.col_number') || ' | ' || pgv.t('crm.col_status') || ' | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF v_activity <> '' THEN
    v_tab_fiche := v_tab_fiche || '<hr><h4>' || pgv.t('crm.title_activity') || '</h4>' || v_activity;
  END IF;

  v_tab_fiche := v_tab_fiche || '<hr>'
    || format('<a href="%s" role="button">%s</a> ', pgv.call_ref('get_client_form', jsonb_build_object('p_id', p_id)), pgv.t('crm.btn_edit'))
    || pgv.action('post_client_delete', pgv.t('crm.btn_delete'), jsonb_build_object('id', p_id), pgv.t('crm.confirm_delete_client'), 'danger');

  -- Timeline (CRM interactions + cross-module)
  v_timeline := '[]'::jsonb;

  FOR r IN SELECT type, subject, body, created_at FROM crm.interaction WHERE client_id = p_id LOOP
    v_timeline := v_timeline || jsonb_build_object(
      'dt', r.created_at, 'badge', crm.type_label(r.type),
      'variant', CASE r.type WHEN 'call' THEN 'primary' WHEN 'visit' THEN 'success' ELSE 'default' END,
      'title', r.subject, 'detail', r.body, 'link', '');
  END LOOP;

  BEGIN
    FOR r IN EXECUTE 'SELECT numero, statut, created_at, id FROM quote.devis WHERE client_id = $1' USING p_id LOOP
      v_timeline := v_timeline || jsonb_build_object(
        'dt', r.created_at, 'badge', pgv.t('crm.cross_quotes'), 'variant', 'warning',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/quote/devis?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    FOR r IN EXECUTE 'SELECT numero, statut, created_at, id FROM quote.facture WHERE client_id = $1' USING p_id LOOP
      v_timeline := v_timeline || jsonb_build_object(
        'dt', r.created_at, 'badge', pgv.t('crm.cross_invoices'), 'variant', 'danger',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/quote/facture?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    FOR r IN EXECUTE 'SELECT numero, statut, created_at, id FROM project.chantier WHERE client_id = $1' USING p_id LOOP
      v_timeline := v_timeline || jsonb_build_object(
        'dt', r.created_at, 'badge', pgv.t('crm.cross_projects'), 'variant', 'primary',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/project/chantier?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF jsonb_array_length(v_timeline) = 0 THEN
    v_interactions := pgv.empty(pgv.t('crm.empty_no_events'));
  ELSE
    v_interactions := pgv.timeline((
      SELECT jsonb_agg(
        jsonb_build_object(
          'date', to_char((e->>'dt')::timestamptz, 'DD/MM/YYYY HH24:MI'),
          'label', (e->>'badge') || E' \u2014 ' || (e->>'title'),
          'detail', nullif(e->>'detail', ''),
          'badge', e->>'variant'
        ) ORDER BY (e->>'dt')::timestamptz DESC
      )
      FROM jsonb_array_elements(v_timeline) AS e
    ));
  END IF;

  v_interactions := v_interactions || pgv.accordion(VARIADIC ARRAY[
    pgv.t('crm.title_add_interaction'),
    pgv.form('post_interaction_add',
      '<input type="hidden" name="client_id" value="' || p_id || '">'
      || pgv.sel('type', pgv.t('crm.field_type'), jsonb_build_array(
           jsonb_build_object('label', pgv.t('crm.type_call'), 'value', 'call'),
           jsonb_build_object('label', pgv.t('crm.type_visit'), 'value', 'visit'),
           jsonb_build_object('label', pgv.t('crm.type_email'), 'value', 'email'),
           jsonb_build_object('label', pgv.t('crm.type_note'), 'value', 'note')
         ), 'note')
      || pgv.input('subject', 'text', pgv.t('crm.field_subject'), NULL, true)
      || pgv.textarea('body', pgv.t('crm.field_details')),
      pgv.t('crm.btn_add'))
  ]);

  v_tab_interactions := v_interactions;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('crm.nav_clients'), pgv.call_ref('get_index'), v_client.name])
    || pgv.tabs(VARIADIC ARRAY[pgv.t('crm.title_fiche'), v_tab_fiche, pgv.t('crm.title_timeline'), v_tab_interactions]);

  RETURN v_body;
END;
$function$;
