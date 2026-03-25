CREATE OR REPLACE FUNCTION stock_ut.test_post_warehouse_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_wh stock.warehouse;
  v_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  v_result := stock.post_warehouse_save(jsonb_build_object(
    'name', 'Test warehouse', 'type', 'workshop', 'address', '1 Test St'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT id INTO v_id FROM stock.warehouse WHERE name = 'Test warehouse' AND tenant_id = 'test';
  SELECT * INTO v_wh FROM stock.warehouse WHERE id = v_id;
  RETURN NEXT ok(FOUND, 'depot created in DB');
  RETURN NEXT is(v_wh.type, 'workshop', 'type saved');
  RETURN NEXT is(v_wh.address, '1 Test St', 'adresse saved');

  v_result := stock.post_warehouse_save(jsonb_build_object(
    'id', v_id, 'name', 'Warehouse modified', 'type', 'job_site', 'address', '2 Mod St'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success');

  SELECT * INTO v_wh FROM stock.warehouse WHERE id = v_id;
  RETURN NEXT is(v_wh.name, 'Warehouse modified', 'nom updated');
  RETURN NEXT is(v_wh.type, 'job_site', 'type updated');

  DELETE FROM stock.warehouse WHERE tenant_id = 'test';
END;
$function$;
