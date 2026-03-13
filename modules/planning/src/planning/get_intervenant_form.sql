CREATE OR REPLACE FUNCTION planning.get_intervenant_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v planning.intervenant;
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v FROM planning.intervenant WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.error('404', pgv.t('planning.err_intervenant_not_found'));
    END IF;
  END IF;

  v_body := pgv.form('post_intervenant_save',
    planning._intervenant_form_inputs(p_id, v.nom, v.role, v.telephone, v.couleur, v.actif)
  , pgv.t('planning.btn_enregistrer'));

  RETURN v_body;
END;
$function$;
