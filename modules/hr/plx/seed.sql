-- HR seed data — 6 employees, balances, leave requests, timesheets
DO $$
DECLARE
  v_e1 int; v_e2 int; v_e3 int; v_e4 int; v_e5 int; v_e6 int;
BEGIN
  INSERT INTO hr.employee (tenant_id, employee_code, last_name, first_name, email, phone, birth_date, gender, nationality, position, qualification, department, contract_type, hire_date, gross_salary, weekly_hours, status, notes)
  VALUES
    ('dev', 'EMP-001', 'Dupont', 'Marie', 'marie.dupont@company.fr', '06 12 34 56 78', '1988-03-15', 'F', 'FR', 'Chef de chantier', '', 'Production', 'cdi', '2018-09-01', 3200, 35, 'active', ''),
    ('dev', 'EMP-002', 'Martin', 'Thomas', 'thomas.martin@company.fr', NULL, '1995-07-22', 'M', 'FR', 'Charpentier', '', 'Production', 'cdi', '2020-03-01', 2800, 35, 'active', ''),
    ('dev', 'EMP-003', 'Lefebvre', 'Claire', 'claire.lefebvre@company.fr', NULL, '1992-11-08', 'F', 'FR', 'Comptable', '', 'Administration', 'cdi', '2019-01-15', 3000, 35, 'active', ''),
    ('dev', 'EMP-004', 'Moreau', 'Lucas', NULL, NULL, NULL, 'M', 'FR', 'Apprenti couvreur', '', 'Production', 'apprenticeship', '2025-09-01', NULL, 35, 'active', ''),
    ('dev', 'EMP-005', 'Rousseau', 'Emma', NULL, NULL, NULL, 'F', 'FR', 'Conductrice de travaux', '', 'Production', 'cdd', '2025-06-01', 3500, 35, 'active', ''),
    ('dev', 'EMP-006', 'Garcia', 'Antoine', NULL, NULL, '1985-02-14', 'M', 'FR', 'Menuisier', '', 'Production', 'cdi', '2010-04-01', NULL, 35, 'inactive', 'Départ retraite')
  ON CONFLICT DO NOTHING;

  SELECT id INTO v_e1 FROM hr.employee WHERE employee_code = 'EMP-001' AND tenant_id = 'dev';
  SELECT id INTO v_e2 FROM hr.employee WHERE employee_code = 'EMP-002' AND tenant_id = 'dev';
  SELECT id INTO v_e3 FROM hr.employee WHERE employee_code = 'EMP-003' AND tenant_id = 'dev';
  SELECT id INTO v_e4 FROM hr.employee WHERE employee_code = 'EMP-004' AND tenant_id = 'dev';
  SELECT id INTO v_e5 FROM hr.employee WHERE employee_code = 'EMP-005' AND tenant_id = 'dev';
  SELECT id INTO v_e6 FROM hr.employee WHERE employee_code = 'EMP-006' AND tenant_id = 'dev';

  IF v_e1 IS NULL THEN RETURN; END IF;

  -- Leave balances
  INSERT INTO hr.leave_balance (tenant_id, employee_id, leave_type, allocated, used) VALUES
    ('dev', v_e1, 'paid_leave', 25, 8), ('dev', v_e1, 'rtt', 10, 3),
    ('dev', v_e2, 'paid_leave', 25, 5), ('dev', v_e2, 'rtt', 10, 2),
    ('dev', v_e3, 'paid_leave', 25, 12), ('dev', v_e3, 'rtt', 10, 5),
    ('dev', v_e4, 'paid_leave', 25, 0),
    ('dev', v_e5, 'paid_leave', 25, 3), ('dev', v_e5, 'rtt', 10, 1)
  ON CONFLICT DO NOTHING;

  -- Leave requests
  INSERT INTO hr.leave_request (tenant_id, employee_id, leave_type, start_date, end_date, day_count, reason, status) VALUES
    ('dev', v_e1, 'paid_leave', '2026-07-14', '2026-07-25', 10, '', 'approved'),
    ('dev', v_e1, 'training', '2026-04-10', '2026-04-11', 2, 'Formation sécurité', 'approved'),
    ('dev', v_e2, 'sick', '2026-05-05', '2026-05-07', 3, '', 'approved'),
    ('dev', v_e2, 'paid_leave', '2026-08-01', '2026-08-15', 11, '', 'pending'),
    ('dev', v_e3, 'rtt', '2026-06-06', '2026-06-06', 1, '', 'approved'),
    ('dev', v_e3, 'paid_leave', '2026-07-28', '2026-08-08', 10, '', 'pending'),
    ('dev', v_e5, 'unpaid', '2026-09-01', '2026-09-05', 5, 'Déménagement', 'pending'),
    ('dev', v_e4, 'paid_leave', '2026-08-18', '2026-08-22', 5, '', 'approved')
  ON CONFLICT DO NOTHING;

  -- Timesheets
  INSERT INTO hr.timesheet (tenant_id, employee_id, work_date, hours, description) VALUES
    ('dev', v_e1, current_date - 3, 8, 'Chantier Villeurbanne'),
    ('dev', v_e1, current_date - 2, 9, 'Chantier Villeurbanne'),
    ('dev', v_e1, current_date - 1, 7.5, 'Bureau + réunion'),
    ('dev', v_e2, current_date - 3, 8, 'Charpente maison'),
    ('dev', v_e2, current_date - 2, 8, 'Charpente maison'),
    ('dev', v_e2, current_date - 1, 8.5, 'Charpente + finitions'),
    ('dev', v_e3, current_date - 2, 7, 'Comptabilité'),
    ('dev', v_e3, current_date - 1, 7, 'Clôture mensuelle'),
    ('dev', v_e5, current_date - 3, 9, 'Coordination Lyon'),
    ('dev', v_e5, current_date - 2, 8, 'Coordination Lyon'),
    ('dev', v_e5, current_date - 1, 8, 'Réunion + planning')
  ON CONFLICT DO NOTHING;
END $$;
