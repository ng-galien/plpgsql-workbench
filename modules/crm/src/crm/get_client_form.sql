CREATE OR REPLACE FUNCTION crm.get_client_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_client crm.client;
  v_title text;
  v_body text;
  v_tags_str text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_client FROM crm.client WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.alert('Client introuvable.', 'danger');
    END IF;
    v_title := 'Modifier ' || pgv.esc(v_client.name);
    v_tags_str := array_to_string(v_client.tags, ', ');
  ELSE
    v_title := 'Nouveau client';
    v_tags_str := '';
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Clients', pgv.call_ref('get_index'),
    v_title
  ]);

  v_body := v_body || '<form data-rpc="client_save">';

  IF p_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || p_id || '">';
  END IF;

  v_body := v_body
    || pgv.sel('type', 'Type', '[{"label":"Particulier","value":"individual"},{"label":"Entreprise","value":"company"}]'::jsonb,
        CASE WHEN p_id IS NOT NULL THEN v_client.type ELSE 'individual' END)
    || pgv.input('name', 'text', 'Nom', v_client.name, true)
    || pgv.input('email', 'email', 'Email', v_client.email)
    || pgv.input('phone', 'tel', 'Téléphone', v_client.phone)
    || pgv.input('address', 'text', 'Adresse', v_client.address)
    || '<div class="grid">'
    || pgv.input('city', 'text', 'Ville', v_client.city)
    || pgv.input('postal_code', 'text', 'Code postal', v_client.postal_code)
    || '</div>'
    || pgv.sel('tier', 'Tier', '["standard","premium","vip"]'::jsonb,
        CASE WHEN p_id IS NOT NULL THEN v_client.tier ELSE 'standard' END)
    || pgv.input('tags', 'text', 'Tags (séparés par virgules)', v_tags_str)
    || pgv.textarea('notes', 'Notes', CASE WHEN p_id IS NOT NULL AND v_client.notes <> '' THEN v_client.notes ELSE NULL END)
    || CASE WHEN p_id IS NOT NULL THEN
        pgv.checkbox('active', 'Client actif', v_client.active)
       ELSE '' END
    || '<button type="submit">' || CASE WHEN p_id IS NOT NULL THEN 'Enregistrer' ELSE 'Créer le client' END || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
