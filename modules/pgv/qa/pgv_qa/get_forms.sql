CREATE OR REPLACE FUNCTION pgv_qa.get_forms()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>Formulaire data-rpc</h4>'
    || '<form data-rpc="form_echo">'
    || pgv.input('p_name', 'text', 'Nom', NULL, true)
    || pgv.input('p_email', 'email', 'Email')
    || pgv.sel('p_role', 'Role', '["admin", "user", "viewer"]'::jsonb, 'user')
    || pgv.textarea('p_notes', 'Notes', 'Texte libre...')
    || '<button type="submit">Envoyer</button>'
    || '</form></section>'
    || '<section><h4>Boutons data-rpc</h4>'
    || '<div class="grid">'
    || pgv.action('toast_success', 'Action simple', NULL::jsonb)
    || pgv.action('toast_success', 'Avec confirmation', NULL::jsonb, 'Etes-vous sur?')
    || pgv.action('toast_error', 'Action danger', NULL::jsonb, NULL, 'danger')
    || pgv.action('toast_success', 'Outline', NULL::jsonb, NULL, 'outline')
    || '</div></section>';
END;
$function$;
