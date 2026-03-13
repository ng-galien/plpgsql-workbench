CREATE OR REPLACE FUNCTION stock.get_depot_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_dep stock.depot;
  v_type_opts jsonb;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_dep FROM stock.depot WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('stock.empty_depot_not_found'), ''); END IF;
  END IF;

  v_type_opts := jsonb_build_array(
    jsonb_build_object('value', '', 'label', pgv.t('stock.ph_type')),
    jsonb_build_object('value', 'atelier', 'label', pgv.t('stock.depot_atelier')),
    jsonb_build_object('value', 'chantier', 'label', pgv.t('stock.depot_chantier')),
    jsonb_build_object('value', 'vehicule', 'label', pgv.t('stock.depot_vehicule')),
    jsonb_build_object('value', 'entrepot', 'label', pgv.t('stock.depot_entrepot'))
  );

  RETURN '<input type="hidden" name="id" value="' || coalesce(p_id::text, '') || '">'
    || pgv.input('nom', 'text', pgv.t('stock.field_nom'), coalesce(pgv.esc(v_dep.nom), ''), true)
    || pgv.sel('type', pgv.t('stock.field_type'), v_type_opts, coalesce(v_dep.type, ''))
    || pgv.input('adresse', 'text', pgv.t('stock.field_adresse'), coalesce(pgv.esc(v_dep.adresse), ''));
END;
$function$;
