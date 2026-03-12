CREATE OR REPLACE FUNCTION purchase_ut.test_fournisseur_options()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_item jsonb;
BEGIN
  v_result := purchase.fournisseur_options();
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'fournisseur_options() returns array');
  RETURN NEXT ok(jsonb_array_length(v_result) > 0, 'fournisseur_options() has items');

  v_item := v_result->0;
  RETURN NEXT ok(v_item ? 'value', 'item has value key');
  RETURN NEXT ok(v_item ? 'label', 'item has label key');
  RETURN NEXT ok(v_item ? 'detail', 'item has detail key');

  v_result := purchase.fournisseur_options('xyz_no_match');
  RETURN NEXT ok(jsonb_array_length(v_result) = 0, 'fournisseur_options(no_match) returns empty');
END;
$function$;
