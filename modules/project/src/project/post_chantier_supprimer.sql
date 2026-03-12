CREATE OR REPLACE FUNCTION project.post_chantier_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_id AND statut = 'preparation') THEN
    RAISE EXCEPTION 'Seuls les chantiers en préparation peuvent être supprimés';
  END IF;
  DELETE FROM project.chantier WHERE id = p_id;
  RETURN '<template data-toast="success">Chantier supprimé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantiers') || '"></template>';
END;
$function$;
