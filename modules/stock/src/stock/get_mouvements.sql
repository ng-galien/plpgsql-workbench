CREATE OR REPLACE FUNCTION stock.get_mouvements()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.id, m.created_at, a.reference, a.designation, d.nom AS depot_nom,
           m.type, m.quantite, m.prix_unitaire, m.reference AS ref_doc,
           dd.nom AS dest_nom
    FROM stock.mouvement m
    JOIN stock.article a ON a.id = m.article_id
    JOIN stock.depot d ON d.id = m.depot_id
    LEFT JOIN stock.depot dd ON dd.id = m.depot_destination_id
    ORDER BY m.created_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM/YY HH24:MI'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.designation),
      pgv.esc(r.depot_nom) || CASE WHEN r.dest_nom IS NOT NULL THEN ' -> ' || pgv.esc(r.dest_nom) ELSE '' END,
      pgv.badge(r.type, CASE r.type
        WHEN 'entree' THEN 'success'
        WHEN 'sortie' THEN 'danger'
        WHEN 'transfert' THEN 'info'
        WHEN 'inventaire' THEN 'warning'
      END),
      r.quantite::text,
      coalesce(r.ref_doc, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucun mouvement', 'Enregistrez votre premier mouvement.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Date', 'Réf.', 'Article', 'Dépôt', 'Type', 'Qté', 'Réf. doc'],
      v_rows, 20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouveau mouvement</a></p>',
    pgv.call_ref('get_mouvement_form'));

  RETURN v_body;
END;
$function$;
