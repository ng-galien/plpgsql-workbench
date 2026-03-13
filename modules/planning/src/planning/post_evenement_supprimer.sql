CREATE OR REPLACE FUNCTION planning.post_evenement_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM planning.evenement WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<template data-toast="error">' || pgv.t('planning.err_evenement_not_found') || '</template>';
  END IF;
  RETURN format('<template data-toast="success">%s</template><template data-redirect="%s"></template>',
    pgv.t('planning.toast_evenement_deleted'),
    pgv.call_ref('get_evenements'));
END;
$function$;
