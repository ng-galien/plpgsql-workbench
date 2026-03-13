CREATE OR REPLACE FUNCTION hr._employee_form_body(p_emp hr.employee DEFAULT NULL::hr.employee)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN CASE WHEN p_emp.id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_emp.id || '">' ELSE '' END
    || '<div class="grid">'
    || pgv.input('nom', 'text', 'Nom', p_emp.nom, true)
    || pgv.input('prenom', 'text', 'Prénom', p_emp.prenom, true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('email', 'email', 'Email', p_emp.email)
    || pgv.input('phone', 'tel', 'Téléphone', p_emp.phone)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('matricule', 'text', 'Matricule', NULLIF(p_emp.matricule, ''))
    || pgv.input('date_naissance', 'date', 'Date de naissance', CASE WHEN p_emp.date_naissance IS NOT NULL THEN to_char(p_emp.date_naissance, 'YYYY-MM-DD') END)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('poste', 'text', 'Poste', NULLIF(p_emp.poste, ''))
    || pgv.input('departement', 'text', 'Département', NULLIF(p_emp.departement, ''))
    || '</div>'
    || '<div class="grid">'
    || pgv.sel('type_contrat', 'Type de contrat', '[{"label":"CDI","value":"cdi"},{"label":"CDD","value":"cdd"},{"label":"Alternance","value":"alternance"},{"label":"Stage","value":"stage"},{"label":"Intérim","value":"interim"}]'::jsonb, COALESCE(p_emp.type_contrat, 'cdi'))
    || pgv.input('date_embauche', 'date', 'Date d''embauche', to_char(COALESCE(p_emp.date_embauche, CURRENT_DATE), 'YYYY-MM-DD'), true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('date_fin', 'date', 'Date de fin (CDD/stage)', CASE WHEN p_emp.date_fin IS NOT NULL THEN to_char(p_emp.date_fin, 'YYYY-MM-DD') END)
    || pgv.input('heures_hebdo', 'number', 'Heures/semaine', COALESCE(p_emp.heures_hebdo, 35)::text)
    || '</div>'
    || pgv.textarea('notes', 'Notes', NULLIF(p_emp.notes, ''));
END;
$function$;
