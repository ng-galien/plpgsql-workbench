CREATE OR REPLACE FUNCTION hr.get_registre(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  v_total int;
  r record;
BEGIN
  v_rows := ARRAY[]::text[];

  FOR r IN
    SELECT e.matricule, e.nom, e.prenom,
           CASE e.sexe WHEN 'M' THEN 'Homme' WHEN 'F' THEN 'Femme' ELSE '—' END AS sexe,
           COALESCE(NULLIF(e.nationalite, ''), '—') AS nationalite,
           CASE WHEN e.date_naissance IS NOT NULL THEN to_char(e.date_naissance, 'DD/MM/YYYY') ELSE '—' END AS date_naissance,
           COALESCE(NULLIF(e.poste, ''), '—') AS emploi,
           COALESCE(NULLIF(e.qualification, ''), '—') AS qualification,
           hr.contrat_label(e.type_contrat) AS contrat,
           to_char(e.date_embauche, 'DD/MM/YYYY') AS date_entree,
           CASE WHEN e.date_fin IS NOT NULL THEN to_char(e.date_fin, 'DD/MM/YYYY') ELSE '—' END AS date_sortie,
           pgv.badge(upper(e.statut), hr.statut_variant(e.statut)) AS statut,
           e.id
      FROM hr.employee e
     ORDER BY e.date_embauche, e.nom, e.prenom
  LOOP
    v_rows := v_rows || ARRAY[
      COALESCE(NULLIF(r.matricule, ''), '—'),
      format('<a href="%s">%s %s</a>', pgv.call_ref('get_employee', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom), pgv.esc(r.prenom)),
      r.sexe,
      r.nationalite,
      r.date_naissance,
      r.emploi,
      r.qualification,
      r.contrat,
      r.date_entree,
      r.date_sortie,
      r.statut
    ];
  END LOOP;

  SELECT count(*)::int INTO v_total FROM hr.employee;

  IF v_total = 0 THEN
    v_body := pgv.empty('Aucun salarié enregistré.');
  ELSE
    v_body := '<p><small>Registre unique du personnel — Art. L1221-13 du Code du travail. ' || v_total || ' salarié(s).</small></p>'
      || pgv.md_table(
        ARRAY['Matricule', 'Nom Prénom', 'Sexe', 'Nationalité', 'Naissance', 'Emploi', 'Qualification', 'Contrat', 'Entrée', 'Sortie', 'Statut'],
        v_rows,
        20
      );
  END IF;

  RETURN v_body;
END;
$function$;
