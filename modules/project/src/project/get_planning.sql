CREATE OR REPLACE FUNCTION project.get_planning()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_body := '<h3>Planning des chantiers actifs</h3>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.numero, cl.name AS client, c.objet,
           project._statut_badge(c.statut) AS statut_badge,
           project._avancement_global(c.id) AS pct,
           c.date_debut, c.date_fin_prevue,
           (SELECT string_agg(
              j.label || ' ' || pgv.badge(
                CASE j.statut WHEN 'valide' THEN '✓' WHEN 'en_cours' THEN j.pct_avancement::text || '%' ELSE '—' END,
                CASE j.statut WHEN 'valide' THEN 'success' WHEN 'en_cours' THEN 'info' ELSE 'default' END
              ), ' '
              ORDER BY j.sort_order
            ) FROM project.jalon j WHERE j.chantier_id = c.id
           ) AS jalons_resume,
           (SELECT count(*)::int FROM project.affectation a WHERE a.chantier_id = c.id) AS nb_intervenants
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
     WHERE c.statut IN ('preparation', 'execution', 'reception')
     ORDER BY c.date_debut NULLS LAST, c.numero
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_chantier', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      pgv.esc(r.client),
      r.statut_badge,
      pgv.badge(r.pct::text || ' %'),
      COALESCE(to_char(r.date_debut, 'DD/MM'), '—') || ' → ' || COALESCE(to_char(r.date_fin_prevue, 'DD/MM'), '—'),
      r.nb_intervenants::text,
      COALESCE(r.jalons_resume, '—')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun chantier actif');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Chantier', 'Client', 'Statut', 'Avancement', 'Période', 'Équipe', 'Jalons'],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
