CREATE OR REPLACE FUNCTION stock.get_movement_form(p_type text DEFAULT 'entry'::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_warehouse_opts jsonb;
  v_type_opts jsonb;
  v_article_search text;
BEGIN
  v_article_search := pgv.select_search(
    'article_id', pgv.t('stock.col_article'),
    'article_options', pgv.t('stock.ph_search_article')
  );

  SELECT coalesce(
    jsonb_build_array(jsonb_build_object('value', '', 'label', pgv.t('stock.ph_depot')))
    || jsonb_agg(jsonb_build_object('value', w.id::text, 'label', w.name) ORDER BY w.name),
    jsonb_build_array(jsonb_build_object('value', '', 'label', pgv.t('stock.ph_depot')))
  ) INTO v_warehouse_opts
  FROM stock.warehouse w WHERE w.active;

  v_type_opts := jsonb_build_array(
    jsonb_build_object('value', 'entry', 'label', pgv.t('stock.type_entree')),
    jsonb_build_object('value', 'exit', 'label', pgv.t('stock.type_sortie')),
    jsonb_build_object('value', 'transfer', 'label', pgv.t('stock.type_transfert')),
    jsonb_build_object('value', 'inventory', 'label', pgv.t('stock.type_inventaire'))
  );

  RETURN pgv.sel('type', pgv.t('stock.field_type'), v_type_opts, p_type)
    || v_article_search
    || pgv.sel('warehouse_id', pgv.t('stock.col_depot'), v_warehouse_opts, '')
    || pgv.input('quantity', 'number', pgv.t('stock.field_quantite'), '', true)
    || pgv.input('unit_price', 'number', pgv.t('stock.field_prix_unitaire'), '')
    || pgv.sel('destination_warehouse_id', pgv.t('stock.field_depot_dest'), v_warehouse_opts, '')
    || pgv.input('reference', 'text', pgv.t('stock.field_ref_doc'), '')
    || pgv.textarea('notes', pgv.t('stock.field_notes'), '');
END;
$function$;
