CREATE OR REPLACE FUNCTION catalog.post_categorie_creer(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO catalog.categorie (nom, parent_id)
  VALUES (
    trim(p_params->>'nom'),
    nullif(p_params->>'parent_id', '')::int
  );

  RETURN '<template data-toast="success">Catégorie créée</template>'
    || format('<template data-redirect="%s"></template>', pgv.call_ref('get_categories'));
END;
$function$;
