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
             THEN ' ' || pgv.badge(pgv.t('purchase.badge_retard'), 'danger')
             ELSE '' END,
        to_char(r.ttc, 'FM999 990.00') || ' EUR',
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty(pgv.t('purchase.empty_no_commande'), pgv.t('purchase.empty_first_commande'))
        || '<p>' || pgv.form_dialog('dlg-new-commande', pgv.t('purchase.title_nouvelle_commande'),
             purchase._commande_form_body(),
             'post_commande_save', pgv.t('purchase.btn_nouvelle_commande')) || '</p>';
    END IF;

    RETURN '<p>' || pgv.form_dialog('dlg-new-commande', pgv.t('purchase.title_nouvelle_commande'),
         purchase._commande_form_body(),
         'post_commande_save', pgv.t('purchase.btn_nouvelle_commande')) || '</p>'
      || pgv.md_table(ARRAY[pgv.t('purchase.col_numero'), pgv.t('purchase.col_fournisseur'), pgv.t('purchase.col_objet'), pgv.t('purchase.col_statut'), pgv.t('purchase.col_total_ttc'), pgv.t('purchase.col_date')], v_rows);
  END IF;

  -- Détail
  SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_id;
  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_cmd.fournisseur_id;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.card(pgv.t('purchase.card_commande'), v_cmd.numero || '<br>' || purchase._statut_badge(v_cmd.statut)),
    pgv.card(pgv.t('purchase.card_fournisseur'), format('<a href="/crm/client?p_id=%s">%s</a>', v_cmd.fournisseur_id, pgv.esc(v_fournisseur))),
    pgv.card(pgv.t('purchase.card_total_ttc'), to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR'),
    pgv.card(pgv.t('purchase.card_livraison'), coalesce(to_char(v_cmd.date_livraison, 'DD/MM/YYYY'), '—'))
  ]);

  -- Workflow progression
  IF v_cmd.statut <> 'annulee' THEN
    v_body := v_body || pgv.workflow(
      jsonb_build_array(
        jsonb_build_object('key', 'brouillon', 'label', pgv.t('purchase.wf_brouillon')),
        jsonb_build_object('key', 'envoyee', 'label', pgv.t('purchase.wf_envoyee')),
        jsonb_build_object('key', 'partiellement_recue', 'label', pgv.t('purchase.wf_partielle')),
        jsonb_build_object('key', 'recue', 'label', pgv.t('purchase.wf_recue'))
      ),
      v_cmd.statut);
  END IF;

  IF v_cmd.objet <> '' THEN
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_objet') || '</strong> ' || pgv.esc(v_cmd.objet) || '</p>';
  END IF;
  IF v_cmd.conditions_paiement <> '' THEN
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_conditions') || '</strong> ' || pgv.esc(v_cmd.conditions_paiement) || '</p>';
  END IF;
  IF v_cmd.notes <> '' THEN
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_notes') || '</strong> ' || pgv.esc(v_cmd.notes) || '</p>';
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
        THEN pgv.action('post_ligne_supprimer', pgv.t('purchase.btn_supprimer'),
               jsonb_build_object('p_ligne_id', r.id),
               pgv.t('purchase.confirm_supprimer_ligne'), 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  v_body := v_body || '<h4>' || pgv.t('purchase.title_lignes') || '</h4>';
  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('purchase.empty_no_ligne'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('purchase.col_description'), pgv.t('purchase.col_qte'), pgv.t('purchase.col_pu'), pgv.t('purchase.col_tva'), pgv.t('purchase.col_total_ht'), pgv.t('purchase.col_restant'), ''],
      v_rows);
    v_body := v_body || '<p><strong>' || pgv.t('purchase.label_total_ht') || '</strong> ' || to_char(purchase._total_ht(p_id), 'FM999 990.00') || ' EUR'
      || ' | <strong>' || pgv.t('purchase.label_tva') || '</strong> ' || to_char(purchase._total_tva(p_id), 'FM999 990.00') || ' EUR'
      || ' | <strong>' || pgv.t('purchase.label_ttc') || '</strong> ' || to_char(purchase._total_ttc(p_id), 'FM999 990.00') || ' EUR</p>';
  END IF;

  -- Formulaire ajout ligne (brouillon)
  IF v_cmd.statut = 'brouillon' THEN
    DECLARE v_add_body text;
    BEGIN
      v_add_body := format('<input type="hidden" name="p_commande_id" value="%s">', p_id)
        || pgv.input('p_description', 'text', pgv.t('purchase.field_description'), NULL, true)
        || '<div class="pgv-grid">'
        || '<label>' || pgv.t('purchase.field_quantite') || '<input type="number" name="p_quantite" value="1" step="0.01" min="0.01"></label>'
        || pgv.sel('p_unite', pgv.t('purchase.field_unite'),
             '[{"value":"u","label":"u"},{"value":"h","label":"h"},{"value":"m","label":"m"},{"value":"m2","label":"m\u00b2"},{"value":"m3","label":"m\u00b3"},{"value":"kg","label":"kg"},{"value":"forfait","label":"forfait"}]'::jsonb, 'u')
        || '<label>' || pgv.t('purchase.field_prix_unitaire') || '<input type="number" name="p_prix_unitaire" step="0.01" min="0" required></label>'
        || pgv.sel('p_tva_rate', pgv.t('purchase.field_tva'),
             '[{"value":"20.00","label":"20%"},{"value":"10.00","label":"10%"},{"value":"5.50","label":"5.5%"},{"value":"0.00","label":"0%"}]'::jsonb, '20.00')
        || '</div>'
        || pgv.select_search('p_article_id', pgv.t('purchase.field_article_stock'), 'article_options', pgv.t('purchase.field_search_article'));
      v_body := v_body || pgv.form_dialog('dlg-add-ligne', pgv.t('purchase.btn_ajouter_ligne'),
        v_add_body,
        'post_ligne_ajouter', pgv.t('purchase.btn_ajouter'));
    END;
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
      r.nb_lignes::text || ' ' || pgv.t('purchase.col_lignes'),
      coalesce(pgv.esc(r.notes), '')
    ];
  END LOOP;

  IF array_length(v_rows_r, 1) IS NOT NULL THEN
    v_body := v_body || '<h4>' || pgv.t('purchase.title_receptions') || '</h4>'
      || pgv.md_table(ARRAY[pgv.t('purchase.col_numero'), pgv.t('purchase.col_date'), pgv.t('purchase.col_lignes'), pgv.t('purchase.col_notes')], v_rows_r);
  END IF;

  -- Bon de commande link
  v_body := v_body || format('<p><a href="%s">%s</a></p>',
    pgv.call_ref('get_bon_commande', jsonb_build_object('p_id', p_id)), pgv.t('purchase.btn_voir_bon'));

  -- Actions
  v_body := v_body || '<p>';
  IF v_cmd.statut = 'brouillon' THEN
    v_body := v_body
      || pgv.form_dialog('dlg-edit-commande', pgv.t('purchase.title_modifier_commande') || ' ' || v_cmd.numero,
           purchase._commande_form_body(p_id),
           'post_commande_save', pgv.t('purchase.btn_modifier'), 'outline') || ' '
      || pgv.action('post_commande_envoyer', pgv.t('purchase.btn_envoyer'),
           jsonb_build_object('p_id', p_id),
           pgv.t('purchase.confirm_envoyer')) || ' '
      || pgv.action('post_commande_annuler', pgv.t('purchase.btn_annuler'),
           jsonb_build_object('p_id', p_id),
           pgv.t('purchase.confirm_annuler'), 'danger');
  ELSIF v_cmd.statut IN ('envoyee', 'partiellement_recue') THEN
    v_body := v_body
      || pgv.action('post_reception_creer', pgv.t('purchase.btn_receptionner'),
           jsonb_build_object('p_commande_id', p_id),
           pgv.t('purchase.confirm_reception')) || ' '
      || pgv.action('post_commande_annuler', pgv.t('purchase.btn_annuler'),
           jsonb_build_object('p_id', p_id),
           pgv.t('purchase.confirm_annuler'), 'danger');
  END IF;
  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
