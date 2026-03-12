CREATE OR REPLACE FUNCTION stock.get_depot_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_dep stock.depot;
  v_type_options text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_dep FROM stock.depot WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Dépôt introuvable', ''); END IF;
  END IF;

  v_type_options := '<option value="">-- Type --</option>';
  v_type_options := v_type_options || format('<option value="atelier"%s>Atelier</option>', CASE WHEN v_dep.type = 'atelier' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="chantier"%s>Chantier</option>', CASE WHEN v_dep.type = 'chantier' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="vehicule"%s>Véhicule</option>', CASE WHEN v_dep.type = 'vehicule' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="entrepot"%s>Entrepôt</option>', CASE WHEN v_dep.type = 'entrepot' THEN ' selected' ELSE '' END);

  RETURN format('<form data-rpc="post_depot_save">
    <input type="hidden" name="id" value="%s">
    <label>Nom <input type="text" name="nom" value="%s" required></label>
    <label>Type <select name="type" required>%s</select></label>
    <label>Adresse <input type="text" name="adresse" value="%s"></label>
    <button type="submit">%s</button>
  </form>',
    coalesce(p_id::text, ''),
    coalesce(pgv.esc(v_dep.nom), ''),
    v_type_options,
    coalesce(pgv.esc(v_dep.adresse), ''),
    CASE WHEN p_id IS NOT NULL THEN 'Modifier' ELSE 'Créer' END
  );
END;
$function$;
