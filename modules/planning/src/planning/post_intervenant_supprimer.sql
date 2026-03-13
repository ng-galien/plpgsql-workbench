CREATE OR REPLACE FUNCTION planning.post_intervenant_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM planning.intervenant WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<template data-toast="error">' || pgv.t('planning.err_intervenant_not_found') || '</template>';
  END IF;
  RETURN format('<template data-toast="success">%s</template><template data-redirect="%s"></template>',
    pgv.t('planning.toast_intervenant_deleted'),
    pgv.call_ref('get_intervenants'));
END;
$function$;
