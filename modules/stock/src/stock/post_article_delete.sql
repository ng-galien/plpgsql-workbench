CREATE OR REPLACE FUNCTION stock.post_article_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stock.article SET active = false WHERE id = (p_data->>'id')::int;

  RETURN pgv.toast(pgv.t('stock.toast_article_desactive'))
    || pgv.redirect(pgv.call_ref('get_articles'));
END;
$function$;
