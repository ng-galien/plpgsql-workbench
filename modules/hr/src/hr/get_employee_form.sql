CREATE OR REPLACE FUNCTION hr.get_employee_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_emp hr.employee;
  v_body text;
  v_title text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_emp FROM hr.employee WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.alert('Salarié introuvable.', 'danger');
    END IF;
    v_title := 'Modifier ' || v_emp.prenom || ' ' || v_emp.nom;
  ELSE
    v_title := 'Nouveau salarié';
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY['Salariés', pgv.call_ref('get_index'), v_title]);

  v_body := v_body || pgv.form('post_employee_save',
    CASE WHEN p_id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_id || '">' ELSE '' END
    || '<div class="grid">'
    || pgv.input('nom', 'text', 'Nom', v_emp.nom, true)
    || pgv.input('prenom', 'text', 'Prénom', v_emp.prenom, true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('email', 'email', 'Email', v_emp.email)
    || pgv.input('phone', 'tel', 'Téléphone', v_emp.phone)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('matricule', 'text', 'Matricule', NULLIF(v_emp.matricule, ''))
    || pgv.input('date_naissance', 'date', 'Date de naissance', CASE WHEN v_emp.date_naissance IS NOT NULL THEN to_char(v_emp.date_naissance, 'YYYY-MM-DD') END)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('poste', 'text', 'Poste', NULLIF(v_emp.poste, ''))
    || pgv.input('departement', 'text', 'Département', NULLIF(v_emp.departement, ''))
    || '</div>'
    || '<div class="grid">'
    || pgv.sel('type_contrat', 'Type de contrat', '[{"label":"CDI","value":"cdi"},{"label":"CDD","value":"cdd"},{"label":"Alternance","value":"alternance"},{"label":"Stage","value":"stage"},{"label":"Intérim","value":"interim"}]'::jsonb, COALESCE(v_emp.type_contrat, 'cdi'))
    || pgv.input('date_embauche', 'date', 'Date d''embauche', to_char(COALESCE(v_emp.date_embauche, CURRENT_DATE), 'YYYY-MM-DD'), true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('date_fin', 'date', 'Date de fin (CDD/stage)', CASE WHEN v_emp.date_fin IS NOT NULL THEN to_char(v_emp.date_fin, 'YYYY-MM-DD') END)
    || pgv.input('heures_hebdo', 'number', 'Heures/semaine', COALESCE(v_emp.heures_hebdo, 35)::text)
    || '</div>'
    || pgv.textarea('notes', 'Notes', NULLIF(v_emp.notes, ''))
    || format('<a href="%s" role="button" class="secondary">Annuler</a>', pgv.call_ref('get_index')),
    'Enregistrer');

  RETURN v_body;
END;
$function$;
