CREATE OR REPLACE FUNCTION quote.get_facture(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  v_ht numeric(12,2);
  v_tva numeric(12,2);
  v_ttc numeric(12,2);
  v_days_since int;
  f record;
  r record;
BEGIN
  -- List mode
  IF p_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT fa.id, fa.numero, fa.client_id, c.name AS client, fa.objet, fa.statut,
             quote._total_ttc(NULL, fa.id) AS ttc, fa.created_at
        FROM quote.facture fa
        JOIN crm.client c ON c.id = fa.client_id
       ORDER BY fa.created_at DESC
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_facture', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
        format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
        pgv.esc(r.objet),
        quote._statut_badge(r.statut),
        to_char(r.ttc, 'FM999 990.00') || ' ' || pgv.t('quote.currency'),
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      v_body := pgv.empty(pgv.t('quote.empty_no_facture'), pgv.t('quote.empty_factures_appear'));
    ELSE
      v_body := pgv.md_table(ARRAY[pgv.t('quote.col_numero'), pgv.t('quote.col_client'), pgv.t('quote.col_objet'), pgv.t('quote.col_statut'), pgv.t('quote.col_total_ttc'), pgv.t('quote.col_date')], v_rows);
    END IF;

    v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>', pgv.call_ref('get_facture_form'), pgv.t('quote.btn_nouvelle_facture'));
    RETURN pgv.breadcrumb(VARIADIC ARRAY[pgv.t('quote.title_factures')]) || v_body;
  END IF;

  -- Detail mode
  SELECT fa.*, c.name AS client_name,
         dv.numero AS devis_numero, dv.id AS devis_pk
    INTO f
    FROM quote.facture fa
    JOIN crm.client c ON c.id = fa.client_id
    LEFT JOIN quote.devis dv ON dv.id = fa.devis_id
   WHERE fa.id = p_id;

  IF NOT FOUND THEN
    RETURN pgv.empty(pgv.t('quote.empty_not_found_facture'));
  END IF;

  v_ht := quote._total_ht(NULL, p_id);
  v_tva := quote._total_tva(NULL, p_id);
  v_ttc := v_ht + v_tva;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('quote.title_factures'), pgv.call_ref('get_facture'),
    f.numero
  ]);

  -- Badge relance si envoyée > 30j
  v_days_since := extract(day FROM now() - f.created_at)::int;

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    pgv.t('quote.field_numero'), f.numero,
    pgv.t('quote.field_client'), format('<a href="/crm/client?p_id=%s">%s</a>', f.client_id, pgv.esc(f.client_name)),
    pgv.t('quote.field_objet'), pgv.esc(f.objet),
    pgv.t('quote.field_statut'), quote._statut_badge(f.statut)
      || CASE WHEN f.statut = 'envoyee' AND v_days_since > 30
           THEN ' ' || pgv.badge(pgv.t('quote.status_relance'), 'danger')
           ELSE ''
         END,
    pgv.t('quote.field_devis'), CASE WHEN f.devis_numero IS NOT NULL
      THEN format('<a href="%s">%s</a>', pgv.call_ref('get_devis', jsonb_build_object('p_id', f.devis_pk)), pgv.esc(f.devis_numero))
      ELSE pgv.t('quote.field_facture_directe')
    END,
    pgv.t('quote.field_date'), to_char(f.created_at, 'DD/MM/YYYY'),
    pgv.t('quote.field_paid_at'), CASE WHEN f.paid_at IS NOT NULL THEN to_char(f.paid_at, 'DD/MM/YYYY') ELSE '—' END,
    pgv.t('quote.field_total_ht'), to_char(v_ht, 'FM999 990.00') || ' ' || pgv.t('quote.currency'),
    pgv.t('quote.field_total_tva'), to_char(v_tva, 'FM999 990.00') || ' ' || pgv.t('quote.currency'),
    pgv.t('quote.field_total_ttc'), to_char(v_ttc, 'FM999 990.00') || ' ' || pgv.t('quote.currency')
  ]);

  -- Lignes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT l.id, l.description, l.quantite, l.unite, l.prix_unitaire, l.tva_rate,
           round(l.quantite * l.prix_unitaire, 2) AS ht
      FROM quote.ligne l
     WHERE l.facture_id = p_id
     ORDER BY l.sort_order, l.id
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.description),
      r.quantite::text,
      r.unite,
      to_char(r.prix_unitaire, 'FM999 990.00'),
      r.tva_rate::text || ' %',
      to_char(r.ht, 'FM999 990.00'),
      CASE WHEN f.statut = 'brouillon'
        THEN pgv.action('post_ligne_supprimer', pgv.t('quote.btn_suppr_ligne'), jsonb_build_object('id', r.id), pgv.t('quote.confirm_supprimer_ligne'), 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('quote.empty_no_ligne'));
  ELSE
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('quote.col_description'), pgv.t('quote.col_quantite'), pgv.t('quote.col_unite'), pgv.t('quote.col_pu_ht'), pgv.t('quote.col_tva'), pgv.t('quote.col_montant_ht'), ''], v_rows);
  END IF;

  -- Formulaire ajout ligne (brouillon uniquement)
  IF f.statut = 'brouillon' THEN
    v_body := v_body || pgv.accordion(VARIADIC ARRAY[
      pgv.t('quote.title_ajouter_ligne'),
      pgv.form('post_ligne_ajouter',
        '<input type="hidden" name="facture_id" value="' || p_id || '">'
        || pgv.select_search('article_id', pgv.t('quote.field_article'), 'quote.article_search', pgv.t('quote.field_article_placeholder'))
        || '<label>' || pgv.t('quote.col_description') || ' <input type="text" name="description" placeholder="' || pgv.t('quote.field_description_placeholder') || '"></label>'
        || '<div class="grid">'
        || '<label>' || pgv.t('quote.field_quantite') || ' <input type="number" name="quantite" value="1" step="0.01" min="0.01" required></label>'
        || '<label>' || pgv.t('quote.col_unite') || ' <select name="unite">'
        || '<option value="u">' || pgv.t('quote.unit_u') || '</option><option value="h">' || pgv.t('quote.unit_h') || '</option>'
        || '<option value="m">' || pgv.t('quote.unit_m') || '</option><option value="m2">' || pgv.t('quote.unit_m2') || '</option>'
        || '<option value="m3">' || pgv.t('quote.unit_m3') || '</option><option value="forfait">' || pgv.t('quote.unit_forfait') || '</option>'
        || '</select></label>'
        || '</div><div class="grid">'
        || '<label>' || pgv.t('quote.field_prix_unitaire') || ' <input type="number" name="prix_unitaire" step="0.01" min="0"></label>'
        || '<label>' || pgv.t('quote.col_tva') || ' <select name="tva_rate">'
        || '<option value="20.00">20 %</option><option value="10.00">10 %</option>'
        || '<option value="5.50">5,5 %</option><option value="0.00">0 %</option>'
        || '</select></label>'
        || '</div>',
        pgv.t('quote.btn_ajouter')
      )
    ]);
  END IF;

  -- Actions selon statut
  v_body := v_body || '<div class="grid">';
  IF f.statut = 'brouillon' THEN
    v_body := v_body
      || format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_facture_form', jsonb_build_object('p_id', p_id)), pgv.t('quote.btn_modifier'))
      || pgv.action('post_facture_envoyer', pgv.t('quote.btn_envoyer'), jsonb_build_object('id', p_id), pgv.t('quote.confirm_envoyer_facture'))
      || pgv.action('post_facture_supprimer', pgv.t('quote.btn_supprimer'), jsonb_build_object('id', p_id), pgv.t('quote.confirm_supprimer_facture'), 'danger');
  ELSIF f.statut = 'envoyee' THEN
    v_body := v_body
      || pgv.action('post_facture_payer', pgv.t('quote.btn_marquer_payee'), jsonb_build_object('id', p_id), pgv.t('quote.confirm_payer_facture'));
    IF v_days_since > 30 THEN
      v_body := v_body
        || pgv.action('post_facture_relancer', pgv.t('quote.btn_relancer'), jsonb_build_object('id', p_id), pgv.t('quote.confirm_relancer_facture'), 'danger');
    END IF;
  END IF;
  v_body := v_body || '</div>';

  IF f.notes <> '' THEN
    v_body := v_body || '<h4>' || pgv.t('quote.field_notes') || '</h4><p>' || pgv.esc(f.notes) || '</p>';
  END IF;

  -- Mentions légales
  v_body := v_body || quote._mentions_html();

  RETURN v_body;
END;
$function$;
