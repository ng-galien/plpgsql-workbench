CREATE OR REPLACE FUNCTION planning.post_desaffecter(p_id integer, p_evenement_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM planning.affectation WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<template data-toast="error">' || pgv.t('planning.toast_affectation_not_found') || '</template>';
  END IF;
  RETURN format('<template data-toast="success">%s</template><template data-redirect="%s"></template>',
    pgv.t('planning.toast_desaffecte'),
    pgv.call_ref('get_evenement', jsonb_build_object('p_id', p_evenement_id)));
END;
$function$;
