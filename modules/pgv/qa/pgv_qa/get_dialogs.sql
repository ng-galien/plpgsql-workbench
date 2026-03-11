CREATE OR REPLACE FUNCTION pgv_qa.get_dialogs()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>Confirmations (data-confirm)</h4>'
    || '<p>Les boutons data-rpc acceptent un attribut data-confirm qui affiche un confirm() natif.</p>'
    || '<div class="grid">'
    || pgv.action('toast_success', 'Action avec confirmation', NULL::jsonb, 'Etes-vous sur de vouloir continuer ?')
    || pgv.action('toast_error', 'Suppression danger', NULL::jsonb, 'Supprimer definitivement ?', 'danger')
    || '</div></section>'
    || '<section><h4>Dialog modale (data-dialog)</h4>'
    || '<p>Le shell possede un dialog reutilisable. Un bouton data-dialog ouvre une modale et charge du contenu depuis data-src.</p>'
    || '<form>'
    || pgv.input('documents_root', 'text', 'Dossier documents', NULL, false)
    || '<button type="button" data-dialog="folder-picker" data-src="/" data-target="documents_root">Parcourir...</button>'
    || '</form></section>'
    || '<section><h4>Toast apres action</h4>'
    || '<p>Les actions serveur retournent un template data-toast. Le shell extrait le message et affiche un toast.</p>'
    || '<div class="grid">'
    || pgv.action('toast_success', 'Toast succes')
    || pgv.action('toast_error', 'Toast erreur', NULL::jsonb, NULL, 'secondary')
    || pgv.action('toast_raise', 'Toast RAISE', NULL::jsonb, NULL, 'contrast')
    || '</div></section>';
END;
$function$;
