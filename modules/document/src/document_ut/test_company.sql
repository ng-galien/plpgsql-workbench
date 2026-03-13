CREATE OR REPLACE FUNCTION document_ut.test_company()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row document.company;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Initially no company
  v_row := document.company_info();
  RETURN NEXT ok(v_row.id IS NULL, 'no company initially');

  -- Upsert: create
  v_row := document.set_company('Acme SAS', '12345678901234', 'FR12345678901', '1 rue Test', 'Paris', '75001', '0100000000', 'test@acme.fr', 'https://acme.fr', 'RCS Paris');
  RETURN NEXT ok(v_row.id IS NOT NULL, 'company created');
  RETURN NEXT is(v_row.name, 'Acme SAS', 'name matches');
  RETURN NEXT is(v_row.siret, '12345678901234', 'siret matches');
  RETURN NEXT is(v_row.city, 'Paris', 'city matches');

  -- Upsert: update
  v_row := document.set_company('Acme SAS Updated', '12345678901234');
  RETURN NEXT is(v_row.name, 'Acme SAS Updated', 'name updated');

  -- Get
  v_row := document.company_info();
  RETURN NEXT is(v_row.name, 'Acme SAS Updated', 'company_info returns updated');

  -- Cleanup
  DELETE FROM document.company WHERE tenant_id = 'test';
END;
$function$;
