CREATE OR REPLACE FUNCTION pgv_qa.page_toast()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>Toasts serveur (data-toast)</h4>'
    || '<p>Chaque bouton POST via data-rpc, le serveur retourne un template data-toast.</p>'
    || '<div class="grid">'
    || '<button data-rpc="toast_success">Toast succes</button>'
    || '<button data-rpc="toast_error" class="secondary">Toast erreur</button>'
    || '</div></section>'
    || '<section><h4>Erreur PostgREST (RAISE)</h4>'
    || '<p>Le serveur RAISE une exception. Le shell parse le JSON PostgREST et affiche un toast.</p>'
    || '<button data-rpc="toast_raise" class="contrast">Declencher RAISE</button>'
    || '</section>';
END;
$function$;
