CREATE OR REPLACE FUNCTION pgv_qa.get_datatable()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN
    '<section><h4>Catalogue produits — FTS + filtres + pagination</h4>'
    || '<p>Recherche full-text avec stemming français et suppression des accents (pgv_search).</p>'
    || pgv.table(jsonb_build_object(
      'rpc',     'data_products',
      'schema',  'pgv_qa',
      'filters', jsonb_build_array(
        jsonb_build_object('name','p_status','type','select','label','Statut',
          'options', jsonb_build_array(
            jsonb_build_array('','Tous'),
            jsonb_build_array('active','Actif'),
            jsonb_build_array('discontinued','Arrêté'))),
        jsonb_build_object('name','p_category','type','select','label','Catégorie',
          'options', jsonb_build_array(
            jsonb_build_array('','Toutes'),
            jsonb_build_array('bois','Bois'),
            jsonb_build_array('quincaillerie','Quincaillerie'),
            jsonb_build_array('chimie','Chimie'),
            jsonb_build_array('panneau','Panneau'),
            jsonb_build_array('isolation','Isolation'))),
        jsonb_build_object('name','q','type','search','label','Recherche FTS')
      ),
      'cols', jsonb_build_array(
        jsonb_build_object('key','id','label','#'),
        jsonb_build_object('key','name','label','Produit'),
        jsonb_build_object('key','category','label','Catégorie','class','pgv-col-badge'),
        jsonb_build_object('key','price','label','Prix'),
        jsonb_build_object('key','status','label','Statut','class','pgv-col-badge')
      ),
      'page_size', 10
    ))
    || '</section>';
END;
$function$;
