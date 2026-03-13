CREATE OR REPLACE FUNCTION crm.get_import()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.breadcrumb(VARIADIC ARRAY[pgv.t('crm.nav_clients'), pgv.call_ref('get_index'), pgv.t('crm.btn_import_csv')])
    || '<p>' || pgv.t('crm.import_intro') || '</p>'
    || '<p><code>nom ; email ; telephone ; adresse ; ville ; code_postal ; type</code></p>'
    || '<p><small>' || pgv.t('crm.import_help') || '</small></p>'
    || pgv.form('post_import_csv',
         pgv.textarea('csv', pgv.t('crm.field_csv'), NULL),
         pgv.t('crm.btn_import'));
END;
$function$;
