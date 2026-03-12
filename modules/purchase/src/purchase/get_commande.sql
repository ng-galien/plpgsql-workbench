CREATE OR REPLACE FUNCTION purchase.get_commande(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd purchase.commande;
  v_fournisseur text;
  v_body text;
  v_rows text[];
  v_rows_r text[];
  r record;
BEGIN
  -- Liste si pas d'id
  IF p_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT c.id, c.fournisseur_id, c.numero, cl.name AS fournisseur, c.objet, c.statut,
             purchase._total_ttc(c.id) AS ttc, c.created_at
        FROM purchase.commande c
        JOIN crm.client cl ON cl.id = c.fournisseur_id
       ORDER BY c.created_at DESC
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_commande', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
        format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur)),
        pgv.esc(r.objet),
        purchase._statut_badge(r.statut)
          || CASE WHEN r.statut IN ('envoyee', 'partiellement_recue')
                      AND r.created_at < now() - interval '14 days'
             THEN ' ' || pgv.badge('retard', 'danger')
             ELSE '' END,
        to_char(r.ttc, 'FM999 990.00') || ' EUR',
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty('Aucune commande', 'Créez votre première commande fournisseur.')
        || format('<p><a href="%s" role="button">Nouvelle commande</a></p>', pgv.call_ref('get_commande_form'));
    END IF;

    RETURN '<p>' || format('<a href="%s" role="button">Nouvelle commande</a>', pgv.call_ref('get_commande_form')) || '</p>'
      || pgv.md_table(ARRAY['Numéro', 'Fournisseur', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows);
  END IF;

  -- Détail
  SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_id;
  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_cmd.fournisseur_id;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.card('Commande', v_cmd.numero || '<br>' || purchase._statut_badge(v_cmd.statut)),
    pgv.card('Fournisseur', format('<a href="/crm/client?p_id=%s">%s</a>', v_cmd.fournisseur_id, pgv.esc(v_fournisseur))),
    pgv.card('Total TTC', to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR'),
    pgv.card('Livraison', coalesce(to_char(v_cmd.date_livraison, 'DD/MM/YYYY'), '—'))
  ]);

  -- Workflow progression
  IF v_cmd.statut <> 'annulee' THEN
    v_body := v_body || pgv.workflow(
      '[{"key":"brouillon","label":"Brouillon"},{"key":"envoyee","label":"Envoyée"},{"key":"partiellement_recue","label":"Partielle"},{"key":"recue","label":"Reçue"}]'::jsonb,
      v_cmd.statut);
  END IF;

  IF v_cmd.objet <> '' THEN
    v_body := v_body || '<p><strong>Objet :</strong> ' || pgv.esc(v_cmd.objet) || '</p>';
  END IF;
  IF v_cmd.conditions_paiement <> '' THEN
    v_body := v_body || '<p><strong>Conditions paiement :</strong> ' || pgv.esc(v_cmd.conditions_paiement) || '</p>';
  END IF;
  IF v_cmd.notes <> '' THEN
    v_body := v_body || '<p><strong>Notes :</strong> ' || pgv.esc(v_cmd.notes) || '</p>';
  END IF;

  -- Lignes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT l.id, l.description, l.quantite, l.unite, l.prix_unitaire, l.tva_rate,
           (l.quantite * l.prix_unitaire) AS total_ht,
           purchase._quantite_restante(l.id) AS restante,
           l.article_id
      FROM purchase.ligne l
     WHERE l.commande_id = p_id
     ORDER BY l.sort_order
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.description) || CASE WHEN r.article_id IS NOT NULL
        THEN ' ' || format('<a href="%s">', pgv.call_ref('get_article_prix', jsonb_build_object('p_article_id', r.article_id)))
          || pgv.badge('art. #' || r.article_id, 'info') || '</a>'
        ELSE '' END,
      r.quantite::text || ' ' || r.unite,
      to_char(r.prix_unitaire, 'FM999 990.00') || ' EUR',
      r.tva_rate::text || '%',
      to_char(r.total_ht, 'FM999 990.00') || ' EUR',
      CASE WHEN v_cmd.statut IN ('envoyee', 'partiellement_recue')
        THEN r.restante::text || ' ' || r.unite
        ELSE '—'
      END,
      CASE WHEN v_cmd.statut = 'brouillon'
        THEN pgv.action('post_ligne_supprimer', 'Supprimer',
               jsonb_build_object('p_ligne_id', r.id),
               'Supprimer cette ligne ?', 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  v_body := v_body || '<h4>Lignes</h4>';
  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune ligne');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Description', 'Qté', 'PU', 'TVA', 'Total HT', 'Restant', ''],
      v_rows);
    v_body := v_body || '<p><strong>Total HT :</strong> ' || to_char(purchase._total_ht(p_id), 'FM999 990.00') || ' EUR'
      || ' | <strong>TVA :</strong> ' || to_char(purchase._total_tva(p_id), 'FM999 990.00') || ' EUR'
      || ' | <strong>TTC :</strong> ' || to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR</p>';
  END IF;

  -- Formulaire ajout ligne (brouillon)
  IF v_cmd.statut = 'brouillon' THEN
    v_body := v_body || '<details><summary>Ajouter une ligne</summary>'
      || '<form data-rpc="post_ligne_ajouter">'
      || format('<input type="hidden" name="p_commande_id" value="%s">', p_id)
      || '<label>Description<input type="text" name="p_description" required></label>'
      || '<div class="pgv-grid">'
      || '<label>Quantité<input type="number" name="p_quantite" value="1" step="0.01" min="0.01"></label>'
      || '<label>Unité<select name="p_unite"><option value="u">u</option><option value="h">h</option><option value="m">m</option><option value="m2">m²</option><option value="m3">m³</option><option value="kg">kg</option><option value="forfait">forfait</option></select></label>'
      || '<label>Prix unitaire<input type="number" name="p_prix_unitaire" step="0.01" min="0" required></label>'
      || '<label>TVA %<select name="p_tva_rate"><option value="20.00" selected>20%</option><option value="10.00">10%</option><option value="5.50">5.5%</option><option value="0.00">0%</option></select></label>'
      || '</div>'
      || pgv.select_search('p_article_id', 'Article stock', 'article_options', 'Rechercher un article...')
      || '<button type="submit">Ajouter</button>'
      || '</form></details>';
  END IF;

  -- Réceptions
  v_rows_r := ARRAY[]::text[];
  FOR r IN
    SELECT rc.id, rc.numero, rc.received_at, rc.notes,
           (SELECT count(*) FROM purchase.reception_ligne rl WHERE rl.reception_id = rc.id) AS nb_lignes
      FROM purchase.reception rc
     WHERE rc.commande_id = p_id
     ORDER BY rc.received_at DESC
  LOOP
    v_rows_r := v_rows_r || ARRAY[
      pgv.esc(r.numero),
      to_char(r.received_at, 'DD/MM/YYYY HH24:MI'),
      r.nb_lignes::text || ' lignes',
      coalesce(pgv.esc(r.notes), '')
    ];
  END LOOP;

  IF array_length(v_rows_r, 1) IS NOT NULL THEN
    v_body := v_body || '<h4>Réceptions</h4>'
      || pgv.md_table(ARRAY['Numéro', 'Date', 'Lignes', 'Notes'], v_rows_r);
  END IF;

  -- Bon de commande link
  v_body := v_body || format('<p><a href="%s">Voir le bon de commande</a></p>',
    pgv.call_ref('get_bon_commande', jsonb_build_object('p_id', p_id)));

  -- Actions
  v_body := v_body || '<p>';
  IF v_cmd.statut = 'brouillon' THEN
    v_body := v_body
      || format('<a href="%s" role="button">Modifier</a> ', pgv.call_ref('get_commande_form', jsonb_build_object('p_id', p_id)))
      || pgv.action('post_commande_envoyer', 'Envoyer',
           jsonb_build_object('p_id', p_id),
           'Marquer cette commande comme envoyée ?') || ' '
      || pgv.action('post_commande_annuler', 'Annuler',
           jsonb_build_object('p_id', p_id),
           'Annuler cette commande ?', 'danger');
  ELSIF v_cmd.statut IN ('envoyee', 'partiellement_recue') THEN
    v_body := v_body
      || pgv.action('post_reception_creer', 'Réceptionner',
           jsonb_build_object('p_commande_id', p_id),
           'Créer une réception pour cette commande ?') || ' '
      || pgv.action('post_commande_annuler', 'Annuler',
           jsonb_build_object('p_id', p_id),
           'Annuler cette commande ?', 'danger');
  END IF;
  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
