CREATE OR REPLACE FUNCTION crm.get_client(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
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
    RETURN pgv.alert('Client introuvable.', 'danger');
  END IF;

  v_fiche := pgv.dl(VARIADIC ARRAY[
    'Type', crm.type_label(v_client.type),
    'Email', COALESCE(v_client.email, '—'),
    'Téléphone', COALESCE(v_client.phone, '—'),
    'Adresse', COALESCE(v_client.address, '—'),
    'Ville', COALESCE(v_client.city, '—'),
    'Code postal', COALESCE(v_client.postal_code, '—'),
    'Tier', pgv.badge(upper(v_client.tier), crm.tier_variant(v_client.tier)),
    'Actif', CASE WHEN v_client.active THEN 'Oui' ELSE 'Non' END,
    'Notes', CASE WHEN v_client.notes = '' THEN '—' ELSE pgv.esc(v_client.notes) END
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
      pgv.esc(r.name) || CASE WHEN r.is_primary THEN ' ' || pgv.badge('Principal', 'primary') ELSE '' END,
      pgv.dl(VARIADIC ARRAY[
        'Rôle', CASE WHEN r.role = '' THEN '—' ELSE pgv.esc(r.role) END,
        'Email', COALESCE(r.email, '—'),
        'Téléphone', COALESCE(r.phone, '—')
      ]),
      pgv.action('post_contact_delete', 'Supprimer', jsonb_build_object('id', r.id), 'Supprimer ce contact ?', 'danger')
    );
  END LOOP;

  IF v_contacts = '' THEN
    v_contacts := pgv.empty('Aucun contact');
  END IF;

  v_contacts := v_contacts ||
    '<details><summary>Ajouter un contact</summary>'
    '<form data-rpc="post_contact_add">'
    '<input type="hidden" name="client_id" value="' || p_id || '">'
    || pgv.input('name', 'text', 'Nom', NULL, true)
    || pgv.input('role', 'text', 'Rôle')
    || pgv.input('email', 'email', 'Email')
    || pgv.input('phone', 'tel', 'Téléphone')
    || pgv.checkbox('is_primary', 'Contact principal')
    || '<button type="submit">Ajouter</button>'
    '</form></details>';

  v_tab_fiche := v_fiche || '<hr>' || '<h4>Contacts</h4>' || v_contacts;

  -- Activité liée (cross-module)
  v_activity := '';
  v_stats := '';

  BEGIN
    EXECUTE 'SELECT count(*) FROM quote.devis WHERE client_id = $1' INTO v_n USING p_id;
    IF v_n > 0 THEN v_stats := v_stats || pgv.stat('Devis', v_n::text); END IF;
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
      v_stats := v_stats || pgv.stat('Factures', v_n::text);
      v_stats := v_stats || pgv.stat('CA TTC', to_char(v_ca, 'FM999G999G990D00') || E' \u20ac');
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    EXECUTE 'SELECT count(*) FROM project.chantier WHERE client_id = $1' INTO v_n USING p_id;
    IF v_n > 0 THEN v_stats := v_stats || pgv.stat('Chantiers', v_n::text); END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF v_stats <> '' THEN
    v_activity := pgv.grid(v_stats) || v_activity;
  END IF;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM quote.devis WHERE client_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [Voir](/' || 'quote/devis?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>Devis</h4><md>' || E'\n' || '| Numéro | Statut | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM project.chantier WHERE client_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [Voir](/' || 'project/chantier?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>Chantiers</h4><md>' || E'\n' || '| Numéro | Statut | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    v_rows := '';
    FOR r IN EXECUTE 'SELECT id, numero, statut FROM purchase.commande WHERE fournisseur_id = $1 ORDER BY id DESC' USING p_id LOOP
      v_rows := v_rows || '| ' || pgv.esc(r.numero::text) || ' | ' || pgv.esc(r.statut::text) || ' | [Voir](/' || 'purchase/commande?p_id=' || r.id || ') |' || E'\n';
    END LOOP;
    IF v_rows <> '' THEN
      v_activity := v_activity || '<h4>Commandes fournisseur</h4><md>' || E'\n' || '| Numéro | Statut | |' || E'\n' || '|--------|--------|-|' || E'\n' || v_rows || '</md>';
    END IF;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF v_activity <> '' THEN
    v_tab_fiche := v_tab_fiche || '<hr><h4>Activité liée</h4>' || v_activity;
  END IF;

  v_tab_fiche := v_tab_fiche || '<hr>'
    || format('<a href="%s" role="button">Modifier</a> ', pgv.call_ref('get_client_form', jsonb_build_object('p_id', p_id)))
    || pgv.action('post_client_delete', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer définitivement ce client et tout son historique ?', 'danger');

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
        'dt', r.created_at, 'badge', 'Devis', 'variant', 'warning',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/quote/devis?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    FOR r IN EXECUTE 'SELECT numero, statut, created_at, id FROM quote.facture WHERE client_id = $1' USING p_id LOOP
      v_timeline := v_timeline || jsonb_build_object(
        'dt', r.created_at, 'badge', 'Facture', 'variant', 'danger',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/quote/facture?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  BEGIN
    FOR r IN EXECUTE 'SELECT numero, statut, created_at, id FROM project.chantier WHERE client_id = $1' USING p_id LOOP
      v_timeline := v_timeline || jsonb_build_object(
        'dt', r.created_at, 'badge', 'Chantier', 'variant', 'primary',
        'title', r.numero::text || E' \u2014 ' || r.statut::text, 'detail', '',
        'link', '/project/chantier?p_id=' || r.id);
    END LOOP;
  EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
  END;

  IF jsonb_array_length(v_timeline) = 0 THEN
    v_interactions := pgv.empty('Aucun evenement');
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

  v_interactions := v_interactions ||
    '<details><summary>Ajouter une interaction</summary>'
    '<form data-rpc="post_interaction_add">'
    '<input type="hidden" name="client_id" value="' || p_id || '">'
    || pgv.sel('type', 'Type', '[{"label":"Appel","value":"call"},{"label":"Visite","value":"visit"},{"label":"Courriel","value":"email"},{"label":"Note","value":"note"}]'::jsonb, 'note')
    || pgv.input('subject', 'text', 'Sujet', NULL, true)
    || pgv.textarea('body', 'Details')
    || '<button type="submit">Ajouter</button>'
    '</form></details>';

  v_tab_interactions := v_interactions;

  v_body := pgv.breadcrumb(VARIADIC ARRAY['Clients', pgv.call_ref('get_index'), v_client.name])
    || pgv.tabs(VARIADIC ARRAY['Fiche', v_tab_fiche, 'Timeline', v_tab_interactions]);

  RETURN v_body;
END;
$function$;
