CREATE OR REPLACE FUNCTION crm.type_label(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE p_type
    WHEN 'individual' THEN pgv.t('crm.type_individual')
    WHEN 'company' THEN pgv.t('crm.type_company')
    WHEN 'call' THEN pgv.t('crm.type_call')
    WHEN 'visit' THEN pgv.t('crm.type_visit')
    WHEN 'email' THEN pgv.t('crm.type_email')
    WHEN 'note' THEN pgv.t('crm.type_note')
    ELSE p_type
  END;
$function$;
