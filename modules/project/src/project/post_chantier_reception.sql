CREATE OR REPLACE FUNCTION project.post_chantier_reception(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE project.chantier
     SET statut = 'reception', updated_at = now()
   WHERE id = p_id AND statut = 'execution';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Chantier introuvable ou pas en cours';
  END IF;
  RETURN '<template data-toast="success">Chantier passé en réception</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_id)) || '"></template>';
END;
$function$;
