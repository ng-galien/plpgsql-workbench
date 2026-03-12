CREATE OR REPLACE FUNCTION project.post_affectation_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_chantier_id int;
  v_statut text;
BEGIN
  SELECT a.chantier_id, c.statut INTO v_chantier_id, v_statut
    FROM project.affectation a
    JOIN project.chantier c ON c.id = a.chantier_id
   WHERE a.id = p_id;

  IF v_statut = 'clos' THEN
    RAISE EXCEPTION 'Impossible de modifier un chantier clos';
  END IF;

  DELETE FROM project.affectation WHERE id = p_id;

  RETURN '<template data-toast="success">Affectation supprimée</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)) || '"></template>';
END;
$function$;
