CREATE OR REPLACE FUNCTION expense_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_n1 int; v_n2 int; v_n3 int; v_n4 int;
  v_cat_meals int; v_cat_travel int; v_cat_hotel int; v_cat_tools int;
BEGIN
  SELECT id INTO v_cat_meals FROM expense.category WHERE name = 'Meals';
  SELECT id INTO v_cat_travel FROM expense.category WHERE name = 'Vehicle travel';
  SELECT id INTO v_cat_hotel FROM expense.category WHERE name = 'Accommodation';
  SELECT id INTO v_cat_tools FROM expense.category WHERE name = 'Tools';

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-001', 'Jean Dupont', '2026-01-01', '2026-01-31', 'reimbursed')
  ON CONFLICT DO NOTHING RETURNING id INTO v_n1;
  IF v_n1 IS NOT NULL THEN
    INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
      (v_n1, '2026-01-05', v_cat_meals, 'Client lunch Leroy', 18.50, 1.85, NULL),
      (v_n1, '2026-01-12', v_cat_travel, 'Marseille job site round trip', 0, 0, 320),
      (v_n1, '2026-01-12', v_cat_hotel, 'Hotel Marseille 1 night', 85.00, 8.50, NULL);
  END IF;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-002', 'Jean Dupont', '2026-02-01', '2026-02-28', 'validated')
  ON CONFLICT DO NOTHING RETURNING id INTO v_n2;
  IF v_n2 IS NOT NULL THEN
    INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
      (v_n2, '2026-02-03', v_cat_tools, 'Bosch circular saw blade', 42.00, 8.40, NULL),
      (v_n2, '2026-02-15', v_cat_meals, 'Team lunch on site', 35.00, 3.50, NULL);
  END IF;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-003', 'Marie Martin', '2026-03-01', '2026-03-10', 'submitted')
  ON CONFLICT DO NOTHING RETURNING id INTO v_n3;
  IF v_n3 IS NOT NULL THEN
    INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
      (v_n3, '2026-03-02', v_cat_travel, 'Supplier visit Lyon', 0, 0, 180),
      (v_n3, '2026-03-02', v_cat_meals, 'Supplier lunch', 22.00, 2.20, NULL),
      (v_n3, '2026-03-08', v_cat_tools, 'Makita driver bits', 15.00, 3.00, NULL);
  END IF;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-004', 'Marie Martin', '2026-03-10', '2026-03-31', 'draft')
  ON CONFLICT DO NOTHING RETURNING id INTO v_n4;
  IF v_n4 IS NOT NULL THEN
    INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
      (v_n4, '2026-03-11', v_cat_travel, 'Aix-en-Provence job site', 0, 0, 90);
  END IF;

  RETURN '4 expense reports seeded (reimbursed, validated, submitted, draft)';
END;
$function$;
