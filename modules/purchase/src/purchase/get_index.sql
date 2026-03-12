CREATE OR REPLACE FUNCTION purchase.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_en_cours int;
  v_receptions_attente int;
  v_factures_impayees int;
  v_achats_mois numeric(12,2);
  v_total_a_payer numeric(12,2);
  v_body text;
  v_rows_c text[];
  v_rows_f text[];
  v_rows_s text[];
  v_en_retard int;
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

  SELECT coalesce(sum(montant_ttc), 0) INTO v_total_a_payer
    FROM purchase.facture_fournisseur WHERE statut IN ('recue', 'validee');

  SELECT count(*)::int INTO v_en_retard
    FROM purchase.commande
   WHERE statut IN ('envoyee', 'partiellement_recue')
     AND created_at < now() - interval '14 days';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Commandes en cours', v_cmd_en_cours::text),
    pgv.stat('A réceptionner', v_receptions_attente::text),
    pgv.stat('Factures impayées', v_factures_impayees::text),
    pgv.stat('Achats du mois', to_char(v_achats_mois, 'FM999 990.00') || ' EUR'),
    pgv.stat('Total à payer', to_char(v_total_a_payer, 'FM999 990.00') || ' EUR'),
    CASE WHEN v_en_retard > 0
      THEN pgv.stat('En retard', v_en_retard::text || ' ' || pgv.badge('> 14j', 'danger'))
      ELSE pgv.stat('En retard', '0')
    END
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
      purchase._statut_badge(r.statut)
        || CASE WHEN r.statut IN ('envoyee', 'partiellement_recue')
                    AND r.created_at < now() - interval '14 days'
           THEN ' ' || pgv.badge('retard', 'danger')
           ELSE '' END,
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

  -- Tab: Top fournisseurs
  v_rows_s := ARRAY[]::text[];
  FOR r IN
    SELECT cl.id AS fournisseur_id, cl.name AS fournisseur,
           count(c.id)::int AS nb_cmd,
           coalesce(sum(purchase._total_ht(c.id)), 0) AS total_ht,
           max(c.created_at) AS last_cmd
      FROM purchase.commande c
      JOIN crm.client cl ON cl.id = c.fournisseur_id
     GROUP BY cl.id, cl.name
     ORDER BY total_ht DESC
     LIMIT 10
  LOOP
    v_rows_s := v_rows_s || ARRAY[
      format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur)),
      r.nb_cmd::text,
      to_char(r.total_ht, 'FM999 990.00') || ' EUR',
      to_char(r.last_cmd, 'DD/MM/YYYY')
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
    END,
    'Top fournisseurs',
    CASE WHEN array_length(v_rows_s, 1) IS NULL
      THEN pgv.empty('Aucune commande')
      ELSE pgv.md_table(ARRAY['Fournisseur', 'Commandes', 'Total achats HT', 'Dernière commande'], v_rows_s)
    END
  ]);

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouvelle commande</a>', pgv.call_ref('get_commande_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
