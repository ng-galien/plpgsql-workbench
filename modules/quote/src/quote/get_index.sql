CREATE OR REPLACE FUNCTION quote.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_devis_en_cours int;
  v_factures_impayees int;
  v_ca_mois numeric(12,2);
  v_taux_acceptation text;
  v_nb_total int;
  v_nb_accepte int;
  v_body text;
  v_rows_d text[];
  v_rows_f text[];
  r record;
BEGIN
  -- Stats
  SELECT count(*)::int INTO v_devis_en_cours
    FROM quote.devis WHERE statut IN ('brouillon', 'envoye');

  SELECT count(*)::int INTO v_factures_impayees
    FROM quote.facture WHERE statut = 'envoyee';

  SELECT coalesce(sum(quote._total_ttc(NULL, f.id)), 0) INTO v_ca_mois
    FROM quote.facture f
   WHERE f.statut = 'payee'
     AND f.paid_at >= date_trunc('month', now());

  SELECT count(*)::int, count(*) FILTER (WHERE statut = 'accepte')::int
    INTO v_nb_total, v_nb_accepte
    FROM quote.devis WHERE statut IN ('accepte', 'refuse');

  IF v_nb_total > 0 THEN
    v_taux_acceptation := round(v_nb_accepte * 100.0 / v_nb_total)::text || ' %';
  ELSE
    v_taux_acceptation := '—';
  END IF;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Devis en cours', v_devis_en_cours::text),
    pgv.stat('Factures impayées', v_factures_impayees::text),
    pgv.stat('CA du mois', to_char(v_ca_mois, 'FM999 990.00') || ' EUR'),
    pgv.stat('Taux acceptation', v_taux_acceptation)
  ]);

  -- Tab 1: Devis récents
  v_rows_d := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.numero, d.client_id, c.name AS client, d.objet, d.statut,
           quote._total_ttc(d.id, NULL) AS ttc, d.created_at
      FROM quote.devis d
      JOIN crm.client c ON c.id = d.client_id
     ORDER BY d.created_at DESC LIMIT 10
  LOOP
    v_rows_d := v_rows_d || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_devis', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
      pgv.esc(r.objet),
      quote._statut_badge(r.statut),
      to_char(r.ttc, 'FM999 990.00') || ' EUR',
      to_char(r.created_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  -- Tab 2: Factures récentes
  v_rows_f := ARRAY[]::text[];
  FOR r IN
    SELECT f.id, f.numero, f.client_id, c.name AS client, f.objet, f.statut,
           quote._total_ttc(NULL, f.id) AS ttc, f.created_at
      FROM quote.facture f
      JOIN crm.client c ON c.id = f.client_id
     ORDER BY f.created_at DESC LIMIT 10
  LOOP
    v_rows_f := v_rows_f || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_facture', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
      pgv.esc(r.objet),
      quote._statut_badge(r.statut),
      to_char(r.ttc, 'FM999 990.00') || ' EUR',
      to_char(r.created_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    'Devis récents',
    CASE WHEN array_length(v_rows_d, 1) IS NULL
      THEN pgv.empty('Aucun devis', 'Créez votre premier devis pour commencer.')
      ELSE pgv.md_table(ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows_d)
    END,
    'Factures récentes',
    CASE WHEN array_length(v_rows_f, 1) IS NULL
      THEN pgv.empty('Aucune facture')
      ELSE pgv.md_table(ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows_f)
    END
  ]);

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouveau devis</a>', pgv.call_ref('get_devis_form'))
    || ' '
    || format('<a href="%s" role="button" class="outline">Nouvelle facture</a>', pgv.call_ref('get_facture_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
