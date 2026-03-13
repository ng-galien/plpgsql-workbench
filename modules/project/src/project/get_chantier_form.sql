CREATE OR REPLACE FUNCTION project.get_chantier_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_id AND statut IN ('preparation','execution')) THEN
      RETURN pgv.empty(pgv.t('project.err_modification_impossible'), pgv.t('project.err_seuls_modifiables'));
    END IF;
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('project.bc_projets'), pgv.call_ref('get_chantiers'),
    CASE WHEN p_id IS NOT NULL THEN pgv.t('project.bc_modifier') ELSE pgv.t('project.bc_nouveau') END
  ]);

  v_body := v_body || pgv.form('post_chantier_save',
    project._chantier_form_fields(p_id),
    CASE WHEN p_id IS NOT NULL THEN pgv.t('project.btn_mettre_a_jour') ELSE pgv.t('project.btn_creer') END);

  RETURN v_body;
END;
$function$;
