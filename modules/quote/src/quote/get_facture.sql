CREATE OR REPLACE FUNCTION quote.get_facture(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  v_ht numeric(12,2);
  v_tva numeric(12,2);
  v_ttc numeric(12,2);
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
        format('<a href="%s">%s</a>', pgv.href('/crm/client?p_id=' || r.client_id), pgv.esc(r.client)),
        pgv.esc(r.objet),
        quote._statut_badge(r.statut),
        to_char(r.ttc, 'FM999 990.00') || ' EUR',
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      v_body := pgv.empty('Aucune facture', 'Les factures apparaîtront ici.');
    ELSE
      v_body := pgv.md_table(ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows);
    END IF;

    v_body := v_body || format('<p><a href="%s" role="button">Nouvelle facture</a></p>', pgv.call_ref('get_facture_form'));
    RETURN pgv.breadcrumb(VARIADIC ARRAY['Factures']) || v_body;
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
    RETURN pgv.empty('Facture introuvable');
  END IF;

  v_ht := quote._total_ht(NULL, p_id);
  v_tva := quote._total_tva(NULL, p_id);
  v_ttc := v_ht + v_tva;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Factures', pgv.call_ref('get_facture'),
    f.numero
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    'Numéro', f.numero,
    'Client', format('<a href="%s">%s</a>', pgv.href('/crm/client?p_id=' || f.client_id), pgv.esc(f.client_name)),
    'Objet', pgv.esc(f.objet),
    'Statut', quote._statut_badge(f.statut),
    'Devis', CASE WHEN f.devis_numero IS NOT NULL
      THEN format('<a href="%s">%s</a>', pgv.call_ref('get_devis', jsonb_build_object('p_id', f.devis_pk)), pgv.esc(f.devis_numero))
      ELSE 'Facture directe'
    END,
    'Date', to_char(f.created_at, 'DD/MM/YYYY'),
    'Payée le', CASE WHEN f.paid_at IS NOT NULL THEN to_char(f.paid_at, 'DD/MM/YYYY') ELSE '—' END,
    'Total HT', to_char(v_ht, 'FM999 990.00') || ' EUR',
    'Total TVA', to_char(v_tva, 'FM999 990.00') || ' EUR',
    'Total TTC', to_char(v_ttc, 'FM999 990.00') || ' EUR'
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
        THEN pgv.action('post_ligne_supprimer', 'Suppr.', jsonb_build_object('id', r.id), 'Supprimer cette ligne ?', 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune ligne');
  ELSE
    v_body := v_body || pgv.md_table(ARRAY['Description', 'Qté', 'Unité', 'PU HT', 'TVA', 'Montant HT', ''], v_rows);
  END IF;

  -- Formulaire ajout ligne (brouillon uniquement)
  IF f.statut = 'brouillon' THEN
    v_body := v_body || '<details><summary>Ajouter une ligne</summary>'
      || '<form data-rpc="post_ligne_ajouter">'
      || '<input type="hidden" name="facture_id" value="' || p_id || '">'
      || '<label>Description <input type="text" name="description" required></label>'
      || '<div class="grid">'
      || '<label>Quantité <input type="number" name="quantite" value="1" step="0.01" min="0.01" required></label>'
      || '<label>Unité <select name="unite">'
      || '<option value="u">Unité</option><option value="h">Heure</option>'
      || '<option value="m">Mètre</option><option value="m2">m²</option>'
      || '<option value="m3">m³</option><option value="forfait">Forfait</option>'
      || '</select></label>'
      || '</div><div class="grid">'
      || '<label>Prix unitaire HT <input type="number" name="prix_unitaire" step="0.01" min="0" required></label>'
      || '<label>TVA <select name="tva_rate">'
      || '<option value="20.00">20 %</option><option value="10.00">10 %</option>'
      || '<option value="5.50">5,5 %</option><option value="0.00">0 %</option>'
      || '</select></label>'
      || '</div>'
      || '<button type="submit">Ajouter</button>'
      || '</form></details>';
  END IF;

  -- Actions selon statut
  v_body := v_body || '<div class="grid">';
  IF f.statut = 'brouillon' THEN
    v_body := v_body
      || format('<a href="%s" role="button" class="outline">Modifier</a>', pgv.call_ref('get_facture_form', jsonb_build_object('p_id', p_id)))
      || pgv.action('post_facture_envoyer', 'Envoyer', jsonb_build_object('id', p_id), 'Marquer cette facture comme envoyée ?')
      || pgv.action('post_facture_supprimer', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer ce brouillon ?', 'danger');
  ELSIF f.statut = 'envoyee' THEN
    v_body := v_body
      || pgv.action('post_facture_payer', 'Marquer payée', jsonb_build_object('id', p_id), 'Marquer cette facture comme payée ?');
  END IF;
  v_body := v_body || '</div>';

  IF f.notes <> '' THEN
    v_body := v_body || '<h4>Notes</h4><p>' || pgv.esc(f.notes) || '</p>';
  END IF;

  RETURN v_body;
END;
$function$;
