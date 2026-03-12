CREATE OR REPLACE FUNCTION quote_ut.test_post_devis_facturer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM quote_ut.test_devis_facturer();
  -- Branche: devis introuvable
  RETURN NEXT throws_ok(
    'SELECT quote.post_devis_facturer(''{"id":999999}''::jsonb)',
    'Devis introuvable'
  );
END;
$function$;
