CREATE OR REPLACE FUNCTION project.post_jalon_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_chantier_id int;
BEGIN
  SELECT j.chantier_id INTO v_chantier_id
    FROM project.jalon j
    JOIN project.chantier c ON c.id = j.chantier_id
   WHERE j.id = p_id AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jalon introuvable ou chantier non modifiable';
  END IF;
  DELETE FROM project.jalon WHERE id = p_id;
  RETURN '<template data-toast="success">Jalon supprimé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)) || '"></template>';
END;
$function$;
