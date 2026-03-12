CREATE OR REPLACE FUNCTION purchase.get_facture_fournisseur(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fac purchase.facture_fournisseur;
  v_cmd_numero text;
  v_fournisseur_id int;
  v_fournisseur_name text;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  -- Liste si pas d'id
  IF p_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT f.id, f.numero_fournisseur, c.numero AS cmd_numero,
             cl.id AS fournisseur_id, cl.name AS fournisseur,
             f.montant_ttc, f.statut, f.date_facture, f.date_echeance
        FROM purchase.facture_fournisseur f
        LEFT JOIN purchase.commande c ON c.id = f.commande_id
        LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
       ORDER BY f.created_at DESC
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero_fournisseur)),
        coalesce(format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur)), '—'),
        coalesce(r.cmd_numero, '—'),
        purchase._statut_badge(r.statut),
        to_char(r.montant_ttc, 'FM999 990.00') || ' EUR',
        to_char(r.date_facture, 'DD/MM/YYYY'),
        coalesce(to_char(r.date_echeance, 'DD/MM/YYYY'), '—')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty('Aucune facture fournisseur', 'Les factures apparaissent ici après saisie.');
    END IF;

    v_body := '<details><summary>Saisir une facture fournisseur</summary>'
      || '<form data-rpc="post_facture_saisir">'
      || '<label>N° fournisseur<input type="text" name="p_numero_fournisseur" required placeholder="ex: FAC-2026-042"></label>'
      || '<div class="pgv-grid">'
      || '<label>Montant HT<input type="number" name="p_montant_ht" step="0.01" min="0" required></label>'
      || '<label>Montant TTC<input type="number" name="p_montant_ttc" step="0.01" min="0" required></label>'
      || '</div>'
      || '<div class="pgv-grid">'
      || '<label>Date facture<input type="date" name="p_date_facture" required></label>'
      || '<label>Date échéance<input type="date" name="p_date_echeance"></label>'
      || '</div>'
      || '<label>Commande liée<select name="p_commande_id"><option value="">(aucune)</option>';
    FOR r IN SELECT id, numero FROM purchase.commande ORDER BY created_at DESC LIMIT 20 LOOP
      v_body := v_body || format('<option value="%s">%s</option>', r.id, pgv.esc(r.numero));
    END LOOP;
    RETURN v_body
      || '</select></label>'
      || '<label>Notes<textarea name="p_notes"></textarea></label>'
      || '<button type="submit">Saisir</button>'
      || '</form></details>'
      || pgv.md_table(ARRAY['N° fournisseur', 'Fournisseur', 'Commande', 'Statut', 'Montant TTC', 'Date facture', 'Echéance'], v_rows);
  END IF;

  -- Détail
  SELECT * INTO v_fac FROM purchase.facture_fournisseur WHERE id = p_id;
  SELECT numero INTO v_cmd_numero FROM purchase.commande WHERE id = v_fac.commande_id;

  -- Fournisseur via commande
  SELECT c.fournisseur_id, cl.name INTO v_fournisseur_id, v_fournisseur_name
    FROM purchase.commande c
    JOIN crm.client cl ON cl.id = c.fournisseur_id
   WHERE c.id = v_fac.commande_id;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.card('Facture', pgv.esc(v_fac.numero_fournisseur) || '<br>' || purchase._statut_badge(v_fac.statut)),
    pgv.card('Fournisseur', CASE WHEN v_fournisseur_id IS NOT NULL
      THEN format('<a href="/crm/client?p_id=%s">%s</a>', v_fournisseur_id, pgv.esc(v_fournisseur_name))
      ELSE '—' END),
    pgv.card('Commande', coalesce(v_cmd_numero, '—')),
    pgv.card('Montant HT', to_char(v_fac.montant_ht, 'FM999 990.00') || ' EUR'),
    pgv.card('Montant TTC', to_char(v_fac.montant_ttc, 'FM999 990.00') || ' EUR')
  ]);

  -- Workflow progression
  v_body := v_body || pgv.workflow(
    '[{"key":"recue","label":"Reçue"},{"key":"validee","label":"Validée"},{"key":"payee","label":"Payée"}]'::jsonb,
    v_fac.statut);

  v_body := v_body || '<p>'
    || '<strong>Date facture :</strong> ' || to_char(v_fac.date_facture, 'DD/MM/YYYY')
    || ' | <strong>Echéance :</strong> ' || coalesce(to_char(v_fac.date_echeance, 'DD/MM/YYYY'), '—')
    || '</p>';

  IF v_fac.notes <> '' THEN
    v_body := v_body || '<p><strong>Notes :</strong> ' || pgv.esc(v_fac.notes) || '</p>';
  END IF;

  -- Rapprochement: comparer montants commande vs facture
  IF v_fac.commande_id IS NOT NULL THEN
    DECLARE
      v_cmd_ttc numeric;
      v_ecart numeric;
    BEGIN
      v_cmd_ttc := purchase._total_ttc(v_fac.commande_id);
      v_ecart := v_fac.montant_ttc - v_cmd_ttc;
      v_body := v_body || '<p><strong>Rapprochement :</strong> Commande TTC = '
        || to_char(v_cmd_ttc, 'FM999 990.00') || ' EUR'
        || ' | Ecart = ' || to_char(v_ecart, 'FM999 990.00') || ' EUR';
      IF abs(v_ecart) > 0.01 THEN
        v_body := v_body || ' ' || pgv.badge('écart', 'warning');
      ELSE
        v_body := v_body || ' ' || pgv.badge('OK', 'success');
      END IF;
      v_body := v_body || '</p>';
    END;
  END IF;

  -- Actions
  v_body := v_body || '<p>';
  IF v_fac.statut = 'recue' THEN
    v_body := v_body || pgv.action('post_facture_valider', 'Valider',
      jsonb_build_object('p_id', p_id),
      'Valider cette facture ?');
  ELSIF v_fac.statut = 'validee' THEN
    v_body := v_body || pgv.action('post_facture_payer', 'Marquer payée',
      jsonb_build_object('p_id', p_id),
      'Marquer cette facture comme payée ?');
  ELSIF v_fac.statut = 'payee' AND NOT v_fac.comptabilisee THEN
    v_body := v_body || pgv.action('post_facture_comptabiliser', 'Comptabiliser',
      jsonb_build_object('p_id', p_id),
      'Créer l''écriture comptable pour cette facture ?');
  END IF;
  IF v_fac.comptabilisee THEN
    v_body := v_body || ' ' || pgv.badge('comptabilisée', 'success');
  END IF;
  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
