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
    hr._employee_form_body(v_emp)
    || pgv.link_button(pgv.call_ref('get_index'), 'Annuler', 'secondary'),
    'Enregistrer');

  RETURN v_body;
END;
$function$;
