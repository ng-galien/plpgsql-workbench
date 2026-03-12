CREATE OR REPLACE FUNCTION stock.get_inventaire(p_depot_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_depot_nom text;
  v_rows text[];
  r record;
  v_qty numeric;
BEGIN
  -- Si pas de dépôt sélectionné, afficher le choix
  IF p_depot_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT d.id, d.nom, d.type FROM stock.depot d WHERE d.actif ORDER BY d.nom
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>',
          pgv.call_ref('get_inventaire', jsonb_build_object('p_depot_id', r.id)),
          pgv.esc(r.nom)),
        pgv.badge(r.type, CASE r.type
          WHEN 'entrepot' THEN 'info'
          WHEN 'atelier' THEN 'success'
          WHEN 'chantier' THEN 'warning'
          WHEN 'vehicule' THEN 'secondary'
        END)
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty('Aucun dépôt', 'Créez un dépôt avant de faire un inventaire.');
    END IF;

    RETURN '<p>Sélectionnez le dépôt à inventorier :</p>' || pgv.md_table(
      ARRAY['Dépôt', 'Type'],
      v_rows
    );
  END IF;

  SELECT nom INTO v_depot_nom FROM stock.depot WHERE id = p_depot_id AND actif;
  IF v_depot_nom IS NULL THEN
    RETURN pgv.empty('Dépôt introuvable', 'Ce dépôt n''existe pas ou est inactif.');
  END IF;

  v_body := format('<h3>Inventaire : %s</h3>', pgv.esc(v_depot_nom));
  v_body := v_body || format('<form data-rpc="post_inventaire_valider"><input type="hidden" name="p_depot_id" value="%s">', p_depot_id);

  -- Liste des articles avec stock théorique
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, a.unite
    FROM stock.article a
    WHERE a.active
    ORDER BY a.designation
  LOOP
    v_qty := stock._stock_actuel(r.id, p_depot_id);
    v_rows := v_rows || ARRAY[
      pgv.esc(r.reference),
      pgv.esc(r.designation),
      r.unite,
      v_qty::text,
      format('<input type="number" name="qty_%s" value="%s" step="0.01" class="pgv-input-sm">', r.id, v_qty)
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun article', 'Aucun article actif dans le catalogue.');
    v_body := v_body || '</form>';
    RETURN v_body;
  END IF;

  v_body := v_body || pgv.md_table(
    ARRAY['Réf.', 'Désignation', 'Unité', 'Théorique', 'Réel'],
    v_rows
  );

  v_body := v_body || '<p><button type="submit" class="pgv-btn-primary">Valider l''inventaire</button></p></form>';

  RETURN v_body;
END;
$function$;
