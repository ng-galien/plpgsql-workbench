CREATE OR REPLACE FUNCTION stock_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  DELETE FROM stock.movement WHERE tenant_id = 'dev';
  DELETE FROM stock.article WHERE tenant_id = 'dev';
  DELETE FROM stock.warehouse WHERE tenant_id = 'dev';
  DELETE FROM crm.client WHERE name IN ('Scierie du Jura', 'Quincaillerie Pro') AND tenant_id = 'dev';
END;
$function$;
