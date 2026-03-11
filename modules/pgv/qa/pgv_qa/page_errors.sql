CREATE OR REPLACE FUNCTION pgv_qa.page_errors()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN
    '<section><h4>Gestion des erreurs du routeur</h4>'
    || '<p>Le routeur attrape les exceptions et rend des pages d''erreur.</p>'
    || '<div class="grid">'
    || pgv.card('404', '<p>Page inexistante</p>', '<a href="' || pgv.href('/nexiste/pas') || '">Tester 404</a>')
    || pgv.card('Erreur metier', '<p>RAISE EXCEPTION</p>', '<a href="' || pgv.href('/test-raise') || '">Tester raise</a>')
    || '</div></section>';
END;
$function$;
