CREATE OR REPLACE FUNCTION quote.get_devis(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  v_ht numeric(12,2);
  v_tva numeric(12,2);
  v_ttc numeric(12,2);
  d record;
  r record;
BEGIN
  -- List mode (no p_id)
  IF p_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT dv.id, dv.numero, c.name AS client, dv.objet, dv.statut,
             quote._total_ttc(dv.id, NULL) AS ttc, dv.created_at
        FROM quote.devis dv
        JOIN crm.client c ON c.id = dv.client_id
       ORDER BY dv.created_at DESC
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_devis', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
        pgv.esc(r.client),
        pgv.esc(r.objet),
        quote._statut_badge(r.statut),
        to_char(r.ttc, 'FM999 990.00') || ' EUR',
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      v_body := pgv.empty('Aucun devis', 'Créez votre premier devis pour commencer.');
    ELSE
      v_body := pgv.md_table(ARRAY['Numéro', 'Client', 'Objet', 'Statut', 'Total TTC', 'Date'], v_rows);
    END IF;

    v_body := v_body || format('<p><a href="%s" role="button">Nouveau devis</a></p>', pgv.call_ref('get_devis_form'));
    RETURN pgv.breadcrumb(VARIADIC ARRAY['Devis']) || v_body;
  END IF;

  -- Detail mode
  SELECT dv.*, c.name AS client_name
    INTO d
    FROM quote.devis dv
    JOIN crm.client c ON c.id = dv.client_id
   WHERE dv.id = p_id;

  IF NOT FOUND THEN
    RETURN pgv.empty('Devis introuvable');
  END IF;

  v_ht := quote._total_ht(p_id, NULL);
  v_tva := quote._total_tva(p_id, NULL);
  v_ttc := v_ht + v_tva;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Devis', pgv.call_ref('get_devis'),
    d.numero
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    'Numéro', d.numero,
    'Client', pgv.esc(d.client_name),
    'Objet', pgv.esc(d.objet),
    'Statut', quote._statut_badge(d.statut),
    'Validité', d.validite_jours || ' jours',
    'Date', to_char(d.created_at, 'DD/MM/YYYY'),
    'Total HT', to_char(v_ht, 'FM999 990.00') || ' EUR',
    'Total TVA', to_char(v_tva, 'FM999 990.00') || ' EUR',
    'Total TTC', to_char(v_ttc, 'FM999 990.00') || ' EUR'
  ]);

  -- Lignes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT l.id, l.description, l.quantite, l.unite, l.prix_unitaire, l.tva_rate,
           round(l.quantite * l.prix_unitaire, 2) AS ht,
           round(l.quantite * l.prix_unitaire * l.tva_rate / 100, 2) AS tva_montant
      FROM quote.ligne l
     WHERE l.devis_id = p_id
     ORDER BY l.sort_order, l.id
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.description),
      r.quantite::text,
      r.unite,
      to_char(r.prix_unitaire, 'FM999 990.00'),
      r.tva_rate::text || ' %',
      to_char(r.ht, 'FM999 990.00'),
      CASE WHEN d.statut = 'brouillon'
        THEN pgv.action('post_ligne_supprimer', 'Suppr.', jsonb_build_object('id', r.id), 'Supprimer cette ligne ?', 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune ligne', 'Ajoutez des lignes à ce devis.');
  ELSE
    v_body := v_body || pgv.md_table(ARRAY['Description', 'Qté', 'Unité', 'PU HT', 'TVA', 'Montant HT', ''], v_rows);
  END IF;

  -- Formulaire ajout ligne (brouillon uniquement)
  IF d.statut = 'brouillon' THEN
    v_body := v_body || '<details><summary>Ajouter une ligne</summary>'
      || '<form data-rpc="post_ligne_ajouter">'
      || '<input type="hidden" name="devis_id" value="' || p_id || '">'
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
  IF d.statut = 'brouillon' THEN
    v_body := v_body
      || format('<a href="%s" role="button" class="outline">Modifier</a>', pgv.call_ref('get_devis_form', jsonb_build_object('p_id', p_id)))
      || pgv.action('post_devis_envoyer', 'Envoyer', jsonb_build_object('id', p_id), 'Marquer ce devis comme envoyé ?')
      || pgv.action('post_devis_supprimer', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer ce brouillon ?', 'danger');
  ELSIF d.statut = 'envoye' THEN
    v_body := v_body
      || pgv.action('post_devis_accepter', 'Accepter', jsonb_build_object('id', p_id), 'Marquer ce devis comme accepté ?')
      || pgv.action('post_devis_refuser', 'Refuser', jsonb_build_object('id', p_id), 'Marquer ce devis comme refusé ?', 'danger');
  ELSIF d.statut = 'accepte' THEN
    v_body := v_body
      || pgv.action('post_devis_facturer', 'Créer la facture', jsonb_build_object('id', p_id), 'Créer une facture depuis ce devis ?');
  END IF;
  v_body := v_body || '</div>';

  IF d.notes <> '' THEN
    v_body := v_body || '<h4>Notes</h4><p>' || pgv.esc(d.notes) || '</p>';
  END IF;

  RETURN v_body;
END;
$function$;
