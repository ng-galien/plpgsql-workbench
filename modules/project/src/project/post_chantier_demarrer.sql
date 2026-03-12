CREATE OR REPLACE FUNCTION project.post_chantier_demarrer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE project.chantier
     SET statut = 'execution',
         date_debut = COALESCE(date_debut, CURRENT_DATE),
         updated_at = now()
   WHERE id = p_id AND statut = 'preparation';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Chantier introuvable ou pas en préparation';
  END IF;
  RETURN '<template data-toast="success">Chantier démarré</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_id)) || '"></template>';
END;
$function$;
