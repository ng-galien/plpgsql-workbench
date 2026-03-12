CREATE OR REPLACE FUNCTION purchase_ut.test_post_ligne_ajouter()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM purchase_ut.test_commande_workflow();
END;
$function$;
