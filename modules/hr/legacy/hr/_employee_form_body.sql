CREATE OR REPLACE FUNCTION hr._employee_form_body(p_emp hr.employee DEFAULT NULL::hr.employee)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN CASE WHEN p_emp.id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_emp.id || '">' ELSE '' END
    || '<div class="grid">'
    || pgv.input('last_name', 'text', 'Nom', p_emp.last_name, true)
    || pgv.input('first_name', 'text', 'Prénom', p_emp.first_name, true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('email', 'email', 'Email', p_emp.email)
    || pgv.input('phone', 'tel', 'Téléphone', p_emp.phone)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('employee_code', 'text', 'Matricule', NULLIF(p_emp.employee_code, ''))
    || pgv.input('birth_date', 'date', 'Date de naissance', CASE WHEN p_emp.birth_date IS NOT NULL THEN to_char(p_emp.birth_date, 'YYYY-MM-DD') END)
    || '</div>'
    || '<div class="grid">'
    || pgv.sel('gender', 'Sexe', '[{"label":"—","value":""},{"label":"Homme","value":"M"},{"label":"Femme","value":"F"}]'::jsonb, COALESCE(p_emp.gender, ''))
    || pgv.input('nationality', 'text', 'Nationalité', NULLIF(p_emp.nationality, ''))
    || '</div>'
    || '<div class="grid">'
    || pgv.input('position', 'text', 'Poste', NULLIF(p_emp.position, ''))
    || pgv.input('department', 'text', 'Département', NULLIF(p_emp.department, ''))
    || '</div>'
    || pgv.input('qualification', 'text', 'Qualification', NULLIF(p_emp.qualification, ''))
    || '<div class="grid">'
    || pgv.sel('contract_type', 'Type de contrat', '[{"label":"CDI","value":"cdi"},{"label":"CDD","value":"cdd"},{"label":"Alternance","value":"apprenticeship"},{"label":"Stage","value":"internship"},{"label":"Intérim","value":"temp"}]'::jsonb, COALESCE(p_emp.contract_type, 'cdi'))
    || pgv.input('hire_date', 'date', 'Date d''embauche', to_char(COALESCE(p_emp.hire_date, CURRENT_DATE), 'YYYY-MM-DD'), true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('end_date', 'date', 'Date de fin (CDD/stage)', CASE WHEN p_emp.end_date IS NOT NULL THEN to_char(p_emp.end_date, 'YYYY-MM-DD') END)
    || pgv.input('weekly_hours', 'number', 'Heures/semaine', COALESCE(p_emp.weekly_hours, 35)::text)
    || '</div>'
    || pgv.textarea('notes', 'Notes', NULLIF(p_emp.notes, ''));
END;
$function$;
