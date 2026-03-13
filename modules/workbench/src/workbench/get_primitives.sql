CREATE OR REPLACE FUNCTION workbench.get_primitives()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  -- Switch prefix so pgv_qa call_ref() resolves to pgv_qa schema
  PERFORM set_config('pgv.route_prefix', '/pgv_qa', true);

  RETURN pgv.tabs(
    'Composants',   pgv_qa.get_atoms(),
    'Tables',       pgv_qa.get_tables(),
    'Formulaires',  pgv_qa.get_forms(),
    'Dialogs',      pgv_qa.get_dialogs(),
    'Toasts',       pgv_qa.get_toast(),
    'SVG',          pgv_qa.get_svg(),
    'Erreurs',      pgv_qa.get_errors()
  );
END;
$function$;
