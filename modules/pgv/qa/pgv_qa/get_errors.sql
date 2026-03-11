CREATE OR REPLACE FUNCTION pgv_qa.get_errors()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_prefix text := coalesce(nullif(current_setting('pgv.route_prefix', true), ''), '');
BEGIN
  RETURN
    '<section><h4>Gestion des erreurs du routeur</h4>'
    || '<p>Le routeur attrape les exceptions et rend des pages d''erreur.</p>'
    || '<div class="grid">'
    || pgv.card('404', '<p>Page inexistante</p>', '<a href="' || v_prefix || '/nexiste/pas">Tester 404</a>')
    || pgv.card('Erreur metier', '<p>RAISE EXCEPTION</p>', '<a href="' || pgv.call_ref('get_test_raise') || '">Tester raise</a>')
    || '</div></section>';
END;
$function$;
