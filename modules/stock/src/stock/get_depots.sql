CREATE OR REPLACE FUNCTION stock.get_depots()
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
    SELECT d.id, d.nom, d.type, d.adresse, d.actif,
           (SELECT count(DISTINCT m.article_id) FROM stock.mouvement m WHERE m.depot_id = d.id)::int AS nb_articles
    FROM stock.depot d
    ORDER BY d.nom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_depot', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom)),
      pgv.badge(r.type, CASE r.type
        WHEN 'atelier' THEN 'success'
        WHEN 'chantier' THEN 'warning'
        WHEN 'vehicule' THEN 'info'
        WHEN 'entrepot' THEN NULL
      END),
      coalesce(r.adresse, '—'),
      r.nb_articles::text,
      CASE WHEN r.actif THEN 'Oui' ELSE 'Non' END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucun dépôt', 'Créez votre premier dépôt pour commencer.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Nom', 'Type', 'Adresse', 'Articles', 'Actif'],
      v_rows
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouveau dépôt</a></p>',
    pgv.call_ref('get_depot_form'));

  RETURN v_body;
END;
$function$;
