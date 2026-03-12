CREATE OR REPLACE FUNCTION catalog_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM catalog.article;
  DELETE FROM catalog.categorie;
  -- Re-seed
  PERFORM catalog_qa.seed();
END;
$function$;
