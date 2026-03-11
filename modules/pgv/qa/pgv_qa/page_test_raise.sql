CREATE OR REPLACE FUNCTION pgv_qa.page_test_raise()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'Ceci est une erreur metier volontaire'
    USING HINT = 'Le routeur attrape les exceptions et rend une page d''erreur.';
END;
$function$;
