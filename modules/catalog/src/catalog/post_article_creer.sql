CREATE OR REPLACE FUNCTION catalog.post_article_creer(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
BEGIN
  INSERT INTO catalog.article (reference, designation, description, categorie_id, unite, prix_vente, prix_achat, tva)
  VALUES (
    nullif(trim(p_params->>'reference'), ''),
    trim(p_params->>'designation'),
    nullif(trim(p_params->>'description'), ''),
    nullif(p_params->>'categorie_id', '')::int,
    coalesce(nullif(p_params->>'unite', ''), 'u'),
    nullif(p_params->>'prix_vente', '')::numeric,
    nullif(p_params->>'prix_achat', '')::numeric,
    coalesce(nullif(p_params->>'tva', '')::numeric, 20.00)
  ) RETURNING id INTO v_id;

  RETURN '<template data-toast="success">Article créé</template>'
    || format('<template data-redirect="%s"></template>',
       pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
END;
$function$;
