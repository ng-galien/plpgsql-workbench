CREATE OR REPLACE FUNCTION stock.get_alertes()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
  v_qty numeric;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, a.unite, a.seuil_mini, a.fournisseur_id,
           c.name AS fournisseur
    FROM stock.article a
    LEFT JOIN crm.client c ON c.id = a.fournisseur_id
    WHERE a.active AND a.seuil_mini > 0
    ORDER BY a.designation
  LOOP
    v_qty := stock._stock_actuel(r.id);
    IF v_qty < r.seuil_mini THEN
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
        pgv.esc(r.designation),
        v_qty::text || ' ' || r.unite,
        r.seuil_mini::text || ' ' || r.unite,
        pgv.badge('ALERTE', 'danger'),
        CASE WHEN r.fournisseur IS NOT NULL
          THEN format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur))
          ELSE '—'
        END
      ];
    END IF;
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucune alerte', 'Tous les articles sont au-dessus du seuil minimum.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Réf.', 'Désignation', 'Stock', 'Seuil', 'Statut', 'Fournisseur'],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
