CREATE OR REPLACE FUNCTION catalog.get_categories()
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
    SELECT c.id, c.nom, p.nom AS parent_nom,
           (SELECT count(*)::int FROM catalog.article a WHERE a.categorie_id = c.id) AS nb_articles
    FROM catalog.categorie c
    LEFT JOIN catalog.categorie p ON p.id = c.parent_id
    ORDER BY coalesce(p.nom, c.nom), c.nom
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.nom),
      coalesce(pgv.esc(r.parent_nom), '—'),
      r.nb_articles::text,
      format('<a href="%s">Articles</a>',
        pgv.call_ref('get_articles', jsonb_build_object('categorie_id', r.id)))
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucune catégorie', 'Créez votre première catégorie.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Nom', 'Parente', 'Articles', 'Voir'],
      v_rows
    );
  END IF;

  -- Formulaire inline ajout catégorie
  v_body := v_body || '<h3>Nouvelle catégorie</h3>';
  v_body := v_body || '<form data-rpc="post_categorie_creer">'
    || '<div class="grid">'
    || pgv.input('nom', 'text', 'Nom', NULL, true);

  -- Select parent
  v_body := v_body || '<label>Catégorie parente<select name="parent_id"><option value="">-- Aucune (racine) --</option>';
  FOR r IN SELECT c.id, c.nom FROM catalog.categorie c WHERE c.parent_id IS NULL ORDER BY c.nom LOOP
    v_body := v_body || format('<option value="%s">%s</option>', r.id, pgv.esc(r.nom));
  END LOOP;
  v_body := v_body || '</select></label>'
    || '</div>'
    || '<button type="submit">Créer</button></form>';

  RETURN v_body;
END;
$function$;
