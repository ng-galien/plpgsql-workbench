CREATE OR REPLACE FUNCTION catalog_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM catalog.article;
  DELETE FROM catalog.category;
  PERFORM catalog_qa.seed();
END;
$function$;
