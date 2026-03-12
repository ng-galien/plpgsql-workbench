CREATE OR REPLACE FUNCTION stock._recalc_pmp(p_article_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_qty numeric := 0;
  v_total_val numeric := 0;
  r record;
BEGIN
  -- Parcourir les entrées chronologiquement pour recalculer le PMP
  FOR r IN
    SELECT quantite, prix_unitaire
    FROM stock.mouvement
    WHERE article_id = p_article_id AND type = 'entree'
    ORDER BY created_at
  LOOP
    v_total_val := v_total_val + (r.quantite * coalesce(r.prix_unitaire, 0));
    v_total_qty := v_total_qty + r.quantite;
  END LOOP;

  UPDATE stock.article
  SET pmp = CASE WHEN v_total_qty > 0 THEN v_total_val / v_total_qty ELSE 0 END
  WHERE id = p_article_id;
END;
$function$;
