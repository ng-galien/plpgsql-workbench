CREATE OR REPLACE FUNCTION crm.get_import()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.breadcrumb(VARIADIC ARRAY['Clients', pgv.call_ref('get_index'), 'Import CSV'])
    || '<p>Collez votre CSV ci-dessous. Colonnes attendues :</p>'
    || '<p><code>nom ; email ; telephone ; adresse ; ville ; code_postal ; type</code></p>'
    || '<p><small>Separateur : <code>;</code> ou <code>,</code> — la ligne d''en-tete est ignoree si elle contient "nom". Le type accepte <code>individual</code> ou <code>company</code> (defaut: individual).</small></p>'
    || '<form data-rpc="post_import_csv">'
    || pgv.textarea('csv', 'Contenu CSV', NULL)
    || '<button type="submit">Importer</button>'
    || '</form>';
END;
$function$;
