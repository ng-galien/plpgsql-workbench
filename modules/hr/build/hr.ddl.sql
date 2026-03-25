-- hr — DDL

CREATE SCHEMA IF NOT EXISTS hr;
CREATE SCHEMA IF NOT EXISTS hr_ut;
CREATE SCHEMA IF NOT EXISTS hr_qa;

-- Employees (staff register)
CREATE TABLE IF NOT EXISTS hr.employee (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  employee_code text NOT NULL DEFAULT '',
  last_name text NOT NULL,
  first_name text NOT NULL,
  email text,
  phone text,
  birth_date date,
  gender text NOT NULL DEFAULT '' CHECK (gender IN ('', 'M', 'F')),
  nationality text NOT NULL DEFAULT '',
  position text NOT NULL DEFAULT '',
  qualification text NOT NULL DEFAULT '',
  department text NOT NULL DEFAULT '',
  contract_type text NOT NULL DEFAULT 'cdi' CHECK (contract_type IN ('cdi', 'cdd', 'apprenticeship', 'internship', 'temp')),
  hire_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  gross_salary numeric,
  weekly_hours numeric NOT NULL DEFAULT 35,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employee_tenant ON hr.employee(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employee_status_name ON hr.employee(status, last_name);

-- Leave requests
CREATE TABLE IF NOT EXISTS hr.leave_request (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  employee_id int NOT NULL REFERENCES hr.employee(id) ON DELETE CASCADE,
  leave_type text NOT NULL CHECK (leave_type IN ('paid_leave', 'rtt', 'sick', 'unpaid', 'training', 'other')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  day_count numeric NOT NULL DEFAULT 1,
  reason text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT leave_request_dates_check CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_leave_request_tenant ON hr.leave_request(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leave_request_employee ON hr.leave_request(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_request_dates ON hr.leave_request(start_date, end_date);

-- Timesheets
CREATE TABLE IF NOT EXISTS hr.timesheet (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  employee_id int NOT NULL REFERENCES hr.employee(id) ON DELETE CASCADE,
  work_date date NOT NULL,
  hours numeric NOT NULL CHECK (hours >= 0 AND hours <= 24),
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT timesheet_employee_date_unique UNIQUE (employee_id, work_date)
);

CREATE INDEX IF NOT EXISTS idx_timesheet_tenant ON hr.timesheet(tenant_id);
CREATE INDEX IF NOT EXISTS idx_timesheet_employee_date ON hr.timesheet(employee_id, work_date DESC);

-- Leave balances
CREATE TABLE IF NOT EXISTS hr.leave_balance (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  employee_id int NOT NULL REFERENCES hr.employee(id) ON DELETE CASCADE,
  leave_type text NOT NULL CHECK (leave_type IN ('paid_leave', 'rtt', 'sick', 'unpaid', 'training', 'other')),
  allocated numeric NOT NULL DEFAULT 0,
  used numeric NOT NULL DEFAULT 0,
  CONSTRAINT leave_balance_unique UNIQUE (employee_id, leave_type),
  CONSTRAINT leave_balance_allocated_positive CHECK (allocated >= 0),
  CONSTRAINT leave_balance_used_positive CHECK (used >= 0)
);

CREATE INDEX IF NOT EXISTS idx_leave_balance_tenant ON hr.leave_balance(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leave_balance_employee ON hr.leave_balance(employee_id);

-- Row Level Security
ALTER TABLE hr.employee ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.leave_request ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.timesheet ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.leave_balance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON hr.employee;
CREATE POLICY tenant_isolation ON hr.employee
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON hr.leave_request;
CREATE POLICY tenant_isolation ON hr.leave_request
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON hr.timesheet;
CREATE POLICY tenant_isolation ON hr.timesheet
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON hr.leave_balance;
CREATE POLICY tenant_isolation ON hr.leave_balance
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Permissions: SELECT only on tables (writes via SECURITY DEFINER functions)
GRANT SELECT ON hr.employee TO anon;
GRANT SELECT ON hr.leave_request TO anon;
GRANT SELECT ON hr.timesheet TO anon;
GRANT SELECT ON hr.leave_balance TO anon;
GRANT USAGE ON SEQUENCE hr.employee_id_seq TO anon;
GRANT USAGE ON SEQUENCE hr.absence_id_seq TO anon;
GRANT USAGE ON SEQUENCE hr.timesheet_id_seq TO anon;
GRANT USAGE ON SEQUENCE hr.leave_balance_id_seq TO anon;
