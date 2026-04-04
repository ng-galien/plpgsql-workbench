CREATE OR REPLACE FUNCTION pgv_ut.test_alert()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(pgv.alert('msg', 'info') LIKE '%pgv-alert-info%', 'alert info has class');
  RETURN NEXT ok(pgv.alert('msg', 'success') LIKE '%pgv-alert-success%', 'alert success has class');
  RETURN NEXT ok(pgv.alert('msg', 'warning') LIKE '%pgv-alert-warning%', 'alert warning has class');
  RETURN NEXT ok(pgv.alert('msg', 'danger') LIKE '%pgv-alert-danger%', 'alert danger has class');
  RETURN NEXT ok(pgv.alert('msg') LIKE '%pgv-alert%', 'alert default has class');
  RETURN NEXT ok(pgv.alert('<b>rich</b>') LIKE '%<b>rich</b>%', 'alert preserves HTML content');
END;
$function$;
