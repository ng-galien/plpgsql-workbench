CREATE OR REPLACE FUNCTION project.post_chantier_clore(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE project.chantier
     SET statut = 'clos',
         date_fin_reelle = COALESCE(date_fin_reelle, CURRENT_DATE),
         updated_at = now()
   WHERE id = p_id AND statut = 'reception';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Chantier introuvable ou pas en réception';
  END IF;
  RETURN '<template data-toast="success">Chantier clos</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_id)) || '"></template>';
END;
$function$;
