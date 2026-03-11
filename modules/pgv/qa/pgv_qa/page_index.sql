CREATE OR REPLACE FUNCTION pgv_qa.page_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_body text;
BEGIN
  v_body := pgv.grid(
    pgv.stat('Items', (SELECT count(*)::text FROM pgv_qa.item), 'total'),
    pgv.stat('Draft', (SELECT count(*)::text FROM pgv_qa.item WHERE status = 'draft'), 'a traiter'),
    pgv.stat('Classes', (SELECT count(*)::text FROM pgv_qa.item WHERE status = 'classified'), 'termine')
  );
  v_body := v_body || '<md data-page="3">' || chr(10)
    || '| Nom | Statut | Date |' || chr(10)
    || '|-----|--------|------|' || chr(10);
  SELECT v_body || coalesce(string_agg(
    '| ' || pgv.esc(name)
    || ' | ' || pgv.badge(status,
        CASE status WHEN 'draft' THEN 'warning' WHEN 'classified' THEN 'success' WHEN 'archived' THEN 'default' ELSE 'info' END)
    || ' | ' || to_char(created_at, 'DD/MM/YYYY') || ' |',
    chr(10) ORDER BY created_at DESC
  ), '') INTO v_body FROM pgv_qa.item;
  v_body := v_body || chr(10) || '</md>';
  RETURN v_body;
END;
$function$;
