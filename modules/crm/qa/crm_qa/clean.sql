CREATE OR REPLACE FUNCTION crm_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM crm.client WHERE name IN (
    'Jean Dupont', 'Menuiserie Leblanc', 'Sophie Martin', 'Charpentes du Sud',
    'Pierre Moreau', 'SARL Toitures Alpines', 'Camille Bernard', 'Ferblanterie Rivière'
  );
  RETURN '<template data-toast="success">Données QA supprimées.</template>';
END;
$function$;
