CREATE OR REPLACE FUNCTION crm_ut.test_display_name()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client crm.client;
BEGIN
  v_client.type := 'individual'; v_client.name := 'Jean Dupont'; v_client.city := 'Lyon';
  RETURN NEXT is(crm.display_name(v_client), 'Jean Dupont', 'individual: name only');

  v_client.type := 'company'; v_client.name := 'ACME'; v_client.city := 'Paris';
  RETURN NEXT is(crm.display_name(v_client), 'ACME (Paris)', 'company with city');

  v_client.type := 'company'; v_client.name := 'ACME'; v_client.city := NULL;
  RETURN NEXT is(crm.display_name(v_client), 'ACME', 'company without city');
END;
$function$;
