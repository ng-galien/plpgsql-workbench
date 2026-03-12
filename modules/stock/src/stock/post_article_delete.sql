CREATE OR REPLACE FUNCTION stock.post_article_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stock.article SET active = false WHERE id = (p_data->>'id')::int;

  RETURN '<template data-toast="success">Article désactivé</template>'
    || format('<template data-redirect="%s"></template>', pgv.call_ref('get_articles'));
END;
$function$;
