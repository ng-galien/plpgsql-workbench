CREATE OR REPLACE FUNCTION stock.get_mouvement_form(p_type text DEFAULT 'entree'::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_depot_opts jsonb;
  v_type_opts jsonb;
  v_article_search text;
BEGIN
  -- Article via select_search
  v_article_search := pgv.select_search(
    'article_id', pgv.t('stock.col_article'),
    'article_options',
    pgv.t('stock.ph_search_article')
  );

  -- Dépôts actifs
  SELECT coalesce(
    jsonb_build_array(jsonb_build_object('value', '', 'label', pgv.t('stock.ph_depot')))
    || jsonb_agg(jsonb_build_object('value', d.id::text, 'label', d.nom) ORDER BY d.nom),
    jsonb_build_array(jsonb_build_object('value', '', 'label', pgv.t('stock.ph_depot')))
  ) INTO v_depot_opts
  FROM stock.depot d WHERE d.actif;

  -- Type
  v_type_opts := jsonb_build_array(
    jsonb_build_object('value', 'entree', 'label', pgv.t('stock.type_entree')),
    jsonb_build_object('value', 'sortie', 'label', pgv.t('stock.type_sortie')),
    jsonb_build_object('value', 'transfert', 'label', pgv.t('stock.type_transfert')),
    jsonb_build_object('value', 'inventaire', 'label', pgv.t('stock.type_inventaire'))
  );

  RETURN pgv.sel('type', pgv.t('stock.field_type'), v_type_opts, p_type)
    || v_article_search
    || pgv.sel('depot_id', pgv.t('stock.col_depot'), v_depot_opts, '')
    || pgv.input('quantite', 'number', pgv.t('stock.field_quantite'), '', true)
    || pgv.input('prix_unitaire', 'number', pgv.t('stock.field_prix_unitaire'), '')
    || pgv.sel('depot_destination_id', pgv.t('stock.field_depot_dest'), v_depot_opts, '')
    || pgv.input('reference', 'text', pgv.t('stock.field_ref_doc'), '')
    || pgv.textarea('notes', pgv.t('stock.field_notes'), '');
END;
$function$;
