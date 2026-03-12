CREATE OR REPLACE FUNCTION stock.get_depot(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_dep stock.depot;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v_dep FROM stock.depot WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty('Dépôt introuvable', ''); END IF;

  v_body := format('<p><strong>Type:</strong> %s | <strong>Adresse:</strong> %s | <strong>Actif:</strong> %s</p>',
    pgv.badge(v_dep.type, NULL),
    coalesce(pgv.esc(v_dep.adresse), '—'),
    CASE WHEN v_dep.actif THEN 'Oui' ELSE 'Non' END
  );

  -- Contenu du dépôt
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, a.unite,
           stock._stock_actuel(a.id, p_id) AS qty
    FROM stock.article a
    WHERE a.active
      AND EXISTS (SELECT 1 FROM stock.mouvement m WHERE m.article_id = a.id AND m.depot_id = p_id)
    ORDER BY a.designation
  LOOP
    IF r.qty <> 0 THEN
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
        pgv.esc(r.designation),
        r.qty::text || ' ' || r.unite
      ];
    END IF;
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Contenu</h3>' || pgv.md_table(
      ARRAY['Réf.', 'Désignation', 'Quantité'],
      v_rows
    );
  ELSE
    v_body := v_body || pgv.empty('Dépôt vide', '');
  END IF;

  -- Derniers mouvements
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, a.designation, m.type, m.quantite, m.reference
    FROM stock.mouvement m
    JOIN stock.article a ON a.id = m.article_id
    WHERE m.depot_id = p_id
    ORDER BY m.created_at DESC
    LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'),
      pgv.esc(r.designation),
      pgv.badge(r.type, CASE r.type
        WHEN 'entree' THEN 'success'
        WHEN 'sortie' THEN 'danger'
        WHEN 'transfert' THEN 'info'
        WHEN 'inventaire' THEN 'warning'
      END),
      r.quantite::text,
      coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Mouvements récents</h3>' || pgv.md_table(
      ARRAY['Date', 'Article', 'Type', 'Qté', 'Réf.'],
      v_rows, 10
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Modifier</a></p>',
    pgv.call_ref('get_depot_form', jsonb_build_object('p_id', p_id)));

  RETURN v_body;
END;
$function$;
