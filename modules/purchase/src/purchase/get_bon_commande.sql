CREATE OR REPLACE FUNCTION purchase.get_bon_commande(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd purchase.commande;
  v_fournisseur record;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty('Commande introuvable'); END IF;

  -- Fournisseur details
  SELECT cl.name, cl.email, cl.phone, cl.address, cl.city
    INTO v_fournisseur
    FROM crm.client cl WHERE cl.id = v_cmd.fournisseur_id;

  -- Header
  v_body := '<div class="pgv-print">';
  v_body := v_body || '<h2>Bon de commande ' || pgv.esc(v_cmd.numero) || '</h2>';

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.card('Fournisseur',
      pgv.esc(v_fournisseur.name)
      || coalesce('<br>' || pgv.esc(v_fournisseur.address), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.city), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.email), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.phone), '')
    ),
    pgv.card('Commande',
      '<strong>N° :</strong> ' || pgv.esc(v_cmd.numero)
      || '<br><strong>Date :</strong> ' || to_char(v_cmd.created_at, 'DD/MM/YYYY')
      || '<br><strong>Objet :</strong> ' || pgv.esc(v_cmd.objet)
      || CASE WHEN v_cmd.date_livraison IS NOT NULL
         THEN '<br><strong>Livraison souhaitée :</strong> ' || to_char(v_cmd.date_livraison, 'DD/MM/YYYY')
         ELSE '' END
      || CASE WHEN v_cmd.conditions_paiement <> ''
         THEN '<br><strong>Paiement :</strong> ' || pgv.esc(v_cmd.conditions_paiement)
         ELSE '' END
    )
  ]);

  -- Lines table
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT l.description, l.quantite, l.unite, l.prix_unitaire, l.tva_rate,
           round(l.quantite * l.prix_unitaire, 2) AS total_ht
      FROM purchase.ligne l
     WHERE l.commande_id = p_id
     ORDER BY l.sort_order
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.description),
      r.quantite::text,
      r.unite,
      to_char(r.prix_unitaire, 'FM999 990.00'),
      r.tva_rate::text || '%',
      to_char(r.total_ht, 'FM999 990.00')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || pgv.md_table(
      ARRAY['Désignation', 'Qté', 'Unité', 'PU HT', 'TVA', 'Total HT'],
      v_rows);
  END IF;

  -- Totals
  v_body := v_body || '<p>'
    || '<strong>Total HT :</strong> ' || to_char(purchase._total_ht(p_id), 'FM999 990.00') || ' EUR'
    || ' | <strong>TVA :</strong> ' || to_char(purchase._total_tva(p_id), 'FM999 990.00') || ' EUR'
    || ' | <strong>Total TTC :</strong> ' || to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR'
    || '</p>';

  IF v_cmd.notes <> '' THEN
    v_body := v_body || '<p><strong>Notes :</strong> ' || pgv.esc(v_cmd.notes) || '</p>';
  END IF;

  v_body := v_body || '</div>';

  -- Back link (hidden in print)
  v_body := v_body || format('<p><a href="%s">Retour à la commande</a></p>',
    pgv.call_ref('get_commande', jsonb_build_object('p_id', p_id)));

  RETURN v_body;
END;
$function$;
