CREATE OR REPLACE FUNCTION purchase.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_en_cours int;
  v_receptions_attente int;
  v_factures_impayees int;
  v_achats_mois numeric(12,2);
  v_body text;
  v_rows_c text[];
  v_rows_f text[];
  r record;
BEGIN
  -- KPIs
  SELECT count(*)::int INTO v_cmd_en_cours
    FROM purchase.commande WHERE statut IN ('envoyee', 'partiellement_recue');

  SELECT count(DISTINCT c.id)::int INTO v_receptions_attente
    FROM purchase.commande c
    JOIN purchase.ligne l ON l.commande_id = c.id
   WHERE c.statut IN ('envoyee', 'partiellement_recue')
     AND purchase._quantite_restante(l.id) > 0;

  SELECT count(*)::int INTO v_factures_impayees
    FROM purchase.facture_fournisseur WHERE statut IN ('recue', 'validee');

  SELECT coalesce(sum(montant_ttc), 0) INTO v_achats_mois
    FROM purchase.facture_fournisseur
   WHERE statut = 'payee'
     AND created_at >= date_trunc('month', now());

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Commandes en cours', v_cmd_en_cours::text),
    pgv.stat('A réceptionner', v_receptions_attente::text),
    pgv.stat('Factures impayées', v_factures_impayees::text),
    pgv.stat('Achats du mois', to_char(v_achats_mois, 'FM999 990.00') || ' EUR')
  ]);

  -- Tab: Commandes récentes
  v_rows_c := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.fournisseur_id, c.numero, cl.name AS fournisseur, c.objet, c.statut,
           purchase._total_ttc(c.id) AS ttc, c.created_at
      FROM purchase.commande c
      JOIN crm.client cl ON cl.id = c.fournisseur_id
     ORDER BY c.created_at DESC LIMIT 10
  LOOP
    v_rows_c := v_rows_c || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_commande', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur)),
      pgv.esc(r.objet),
      purchase._statut_badge(r.statut),
      to_char(r.ttc, 'FM999 990.00') || ' EUR',
      to_char(r.created_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  -- Tab: Factures récentes
  v_rows_f := ARRAY[]::text[];
  FOR r IN
    SELECT f.id, f.numero_fournisseur, c.numero AS cmd_numero,
           f.montant_ttc, f.statut, f.date_facture, f.date_echeance
      FROM purchase.facture_fournisseur f
      LEFT JOIN purchase.commande c ON c.id = f.commande_id
     ORDER BY f.created_at DESC LIMIT 10
  LOOP
    v_rows_f := v_rows_f || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero_fournisseur)),
      coalesce(r.cmd_numero, '—'),
      purchase._statut_badge(r.statut),
      to_char(r.montant_ttc, 'FM999 990.00') || ' EUR',
      to_char(r.date_facture, 'DD/MM/YYYY'),
      coalesce(to_char(r.date_echeance, 'DD/MM/YYYY'), '—')
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    'Commandes récentes',
    CASE WHEN array_length(v_rows_c, 1) IS NULL
      THEN pgv.empty('Aucune commande', 'Créez votre première commande fournisseur.')
      ELSE pgv.md_table(ARRAY['Numéro', 'Fournisseur', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows_c)
    END,
    'Factures fournisseur',
    CASE WHEN array_length(v_rows_f, 1) IS NULL
      THEN pgv.empty('Aucune facture fournisseur')
      ELSE pgv.md_table(ARRAY['N° fournisseur', 'Commande', 'Statut', 'Montant TTC', 'Date facture', 'Echéance'], v_rows_f)
    END
  ]);

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouvelle commande</a>', pgv.call_ref('get_commande_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
