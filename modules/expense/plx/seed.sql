-- Expense seed data — reference categories + demo reports
DO $$
DECLARE
  v_cat_travel int; v_cat_meals int; v_cat_tools int;
  v_r1 int; v_r2 int; v_r3 int; v_r4 int;
BEGIN
  -- Reference categories
  INSERT INTO expense.category (name, accounting_code) VALUES
    ('Vehicle travel', '625100'),
    ('Transport (train, plane)', '625200'),
    ('Accommodation', '625600'),
    ('Meals', '625700'),
    ('Supplies', '606400'),
    ('Tools', '606300'),
    ('Phone/Internet', '626000'),
    ('Miscellaneous', '625800')
  ON CONFLICT DO NOTHING;

  SELECT id INTO v_cat_travel FROM expense.category WHERE accounting_code = '625100';
  SELECT id INTO v_cat_meals FROM expense.category WHERE accounting_code = '625700';
  SELECT id INTO v_cat_tools FROM expense.category WHERE accounting_code = '606300';

  -- Demo expense reports
  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-001', 'Jean Dupont', '2026-01-01', '2026-01-31', 'reimbursed')
  ON CONFLICT (reference) DO NOTHING
  RETURNING id INTO v_r1;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-002', 'Jean Dupont', '2026-02-01', '2026-02-28', 'validated')
  ON CONFLICT (reference) DO NOTHING
  RETURNING id INTO v_r2;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-003', 'Marie Martin', '2026-03-01', '2026-03-10', 'submitted')
  ON CONFLICT (reference) DO NOTHING
  RETURNING id INTO v_r3;

  INSERT INTO expense.expense_report (reference, author, start_date, end_date, status)
  VALUES ('NDF-2026-004', 'Marie Martin', '2026-03-10', '2026-03-31', 'draft')
  ON CONFLICT (reference) DO NOTHING
  RETURNING id INTO v_r4;

  IF v_r1 IS NULL THEN RETURN; END IF;

  -- Lines for report 1 (reimbursed)
  INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
    (v_r1, '2026-01-05', v_cat_meals, 'Déjeuner client Lyon', 28.50, 5.70, NULL),
    (v_r1, '2026-01-12', v_cat_travel, 'Trajet Lyon-Grenoble AR', 0, 0, 320),
    (v_r1, '2026-01-12', NULL, 'Hôtel Grenoble', 65.00, 13.00, NULL);

  -- Lines for report 2 (validated)
  INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat) VALUES
    (v_r2, '2026-02-03', v_cat_tools, 'Disqueuse Bosch', 62.00, 12.40),
    (v_r2, '2026-02-10', v_cat_meals, 'Déjeuner équipe', 14.00, 0);

  -- Lines for report 3 (submitted)
  INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
    (v_r3, '2026-03-02', v_cat_travel, 'Trajet Nantes-Angers', 0, 0, 180),
    (v_r3, '2026-03-05', v_cat_meals, 'Déjeuner chantier', 12.50, 2.50, NULL),
    (v_r3, '2026-03-08', v_cat_tools, 'Mètre laser', 22.00, 4.40, NULL);

  -- Lines for report 4 (draft)
  INSERT INTO expense.line (note_id, expense_date, category_id, description, amount_excl_tax, vat, km) VALUES
    (v_r4, '2026-03-15', v_cat_travel, 'Trajet bureau-chantier', 0, 0, 90);
END $$;
