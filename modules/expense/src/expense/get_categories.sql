CREATE OR REPLACE FUNCTION expense.get_categories()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT id, nom, code_comptable FROM expense.categorie ORDER BY nom LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.nom),
      coalesce(pgv.esc(r.code_comptable), '—')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    RETURN pgv.empty(pgv.t('expense.empty_no_categorie'));
  END IF;

  RETURN pgv.md_table(ARRAY[pgv.t('expense.col_categorie'), pgv.t('expense.col_code_comptable')], v_rows);
END;
$function$;
