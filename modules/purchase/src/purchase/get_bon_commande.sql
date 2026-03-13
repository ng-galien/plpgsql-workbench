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
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('purchase.empty_commande_introuvable')); END IF;

  -- Fournisseur details
  SELECT cl.name, cl.email, cl.phone, cl.address, cl.city
    INTO v_fournisseur
    FROM crm.client cl WHERE cl.id = v_cmd.fournisseur_id;

  -- Header
  v_body := '<div class="pgv-print">';
  v_body := v_body || '<h2>' || pgv.t('purchase.title_bon_commande') || ' ' || pgv.esc(v_cmd.numero) || '</h2>';

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.card(pgv.t('purchase.card_fournisseur'),
      pgv.esc(v_fournisseur.name)
      || coalesce('<br>' || pgv.esc(v_fournisseur.address), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.city), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.email), '')
      || coalesce('<br>' || pgv.esc(v_fournisseur.phone), '')
    ),
    pgv.card(pgv.t('purchase.card_commande'),
      '<strong>' || pgv.t('purchase.label_no') || '</strong> ' || pgv.esc(v_cmd.numero)
      || '<br><strong>' || pgv.t('purchase.label_date') || '</strong> ' || to_char(v_cmd.created_at, 'DD/MM/YYYY')
      || '<br><strong>' || pgv.t('purchase.label_objet') || '</strong> ' || pgv.esc(v_cmd.objet)
      || CASE WHEN v_cmd.date_livraison IS NOT NULL
         THEN '<br><strong>' || pgv.t('purchase.label_livraison_souhaitee') || '</strong> ' || to_char(v_cmd.date_livraison, 'DD/MM/YYYY')
         ELSE '' END
      || CASE WHEN v_cmd.conditions_paiement <> ''
         THEN '<br><strong>' || pgv.t('purchase.label_paiement') || '</strong> ' || pgv.esc(v_cmd.conditions_paiement)
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
      ARRAY[pgv.t('purchase.col_designation'), pgv.t('purchase.col_qte'), pgv.t('purchase.col_unite'), pgv.t('purchase.col_pu_ht'), pgv.t('purchase.col_tva'), pgv.t('purchase.col_total_ht')],
      v_rows);
  END IF;

  -- Totals
  v_body := v_body || '<p>'
    || '<strong>' || pgv.t('purchase.label_total_ht') || '</strong> ' || to_char(purchase._total_ht(p_id), 'FM999 990.00') || ' EUR'
    || ' | <strong>' || pgv.t('purchase.label_tva') || '</strong> ' || to_char(purchase._total_tva(p_id), 'FM999 990.00') || ' EUR'
    || ' | <strong>' || pgv.t('purchase.label_total_ttc') || '</strong> ' || to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR'
    || '</p>';

  IF v_cmd.notes <> '' THEN
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_notes') || '</strong> ' || pgv.esc(v_cmd.notes) || '</p>';
  END IF;

  v_body := v_body || '</div>';

  -- Back link (hidden in print)
  v_body := v_body || format('<p><a href="%s">%s</a></p>',
    pgv.call_ref('get_commande', jsonb_build_object('p_id', p_id)), pgv.t('purchase.btn_retour_commande'));

  RETURN v_body;
END;
$function$;
