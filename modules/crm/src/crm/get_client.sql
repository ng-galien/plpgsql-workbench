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
      pgv.action('contact_delete', 'Supprimer', jsonb_build_object('id', r.id), 'Supprimer ce contact ?', 'danger')
    );
  END LOOP;

  IF v_contacts = '' THEN
    v_contacts := pgv.empty('Aucun contact');
  END IF;

  v_contacts := v_contacts ||
    '<details><summary>Ajouter un contact</summary>'
    '<form data-rpc="contact_add">'
    '<input type="hidden" name="client_id" value="' || p_id || '">'
    || pgv.input('name', 'text', 'Nom', NULL, true)
    || pgv.input('role', 'text', 'Rôle')
    || pgv.input('email', 'email', 'Email')
    || pgv.input('phone', 'tel', 'Téléphone')
    || pgv.checkbox('is_primary', 'Contact principal')
    || '<button type="submit">Ajouter</button>'
    '</form></details>';

  v_tab_fiche := v_fiche || '<hr>' || '<h4>Contacts</h4>' || v_contacts;

  v_tab_fiche := v_tab_fiche || '<hr>'
    || format('<a href="%s" role="button">Modifier</a> ', pgv.call_ref('get_client_form', jsonb_build_object('p_id', p_id)))
    || pgv.action('client_delete', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer définitivement ce client et tout son historique ?', 'danger');

  v_interactions := '';
  FOR r IN SELECT * FROM crm.interaction WHERE client_id = p_id ORDER BY created_at DESC LOOP
    v_interactions := v_interactions || pgv.card(
      pgv.badge(crm.type_label(r.type), 'default') || ' ' || pgv.esc(r.subject),
      CASE WHEN r.body = '' THEN '<p><em>Pas de détail</em></p>' ELSE '<p>' || pgv.esc(r.body) || '</p>' END,
      '<small>' || to_char(r.created_at, 'DD/MM/YYYY HH24:MI') || '</small>'
    );
  END LOOP;

  IF v_interactions = '' THEN
    v_interactions := pgv.empty('Aucune interaction');
  END IF;

  v_interactions := v_interactions ||
    '<details><summary>Ajouter une interaction</summary>'
    '<form data-rpc="interaction_add">'
    '<input type="hidden" name="client_id" value="' || p_id || '">'
    || pgv.sel('type', 'Type', '[{"label":"Appel","value":"call"},{"label":"Visite","value":"visit"},{"label":"Courriel","value":"email"},{"label":"Note","value":"note"}]'::jsonb, 'note')
    || pgv.input('subject', 'text', 'Sujet', NULL, true)
    || pgv.textarea('body', 'Détails')
    || '<button type="submit">Ajouter</button>'
    '</form></details>';

  v_tab_interactions := v_interactions;

  v_body := pgv.breadcrumb(VARIADIC ARRAY['Clients', pgv.call_ref('get_index'), v_client.name])
    || pgv.tabs(VARIADIC ARRAY['Fiche', v_tab_fiche, 'Interactions', v_tab_interactions]);

  RETURN v_body;
END;
$function$;
