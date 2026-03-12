CREATE OR REPLACE FUNCTION project.post_pointage_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_chantier_id int;
BEGIN
  SELECT p.chantier_id INTO v_chantier_id
    FROM project.pointage p
    JOIN project.chantier c ON c.id = p.chantier_id
   WHERE p.id = p_id AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pointage introuvable ou chantier non modifiable';
  END IF;
  DELETE FROM project.pointage WHERE id = p_id;
  RETURN '<template data-toast="success">Pointage supprimé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)) || '"></template>';
END;
$function$;
