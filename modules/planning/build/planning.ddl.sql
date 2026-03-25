-- planning — DDL

CREATE SCHEMA IF NOT EXISTS planning;
CREATE SCHEMA IF NOT EXISTS planning_ut;
CREATE SCHEMA IF NOT EXISTS planning_qa;

-- Workers (team: workers, subcontractors, team leads)
CREATE TABLE IF NOT EXISTS planning.worker (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name text NOT NULL,
  role text NOT NULL DEFAULT '',
  phone text,
  color text NOT NULL DEFAULT '#3b82f6',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_worker_tenant ON planning.worker(tenant_id);
CREATE INDEX IF NOT EXISTS idx_worker_active ON planning.worker(active, name);

-- Events (scheduled slots — linked or not to a project)
CREATE TABLE IF NOT EXISTS planning.event (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  title text NOT NULL,
  type text NOT NULL DEFAULT 'job_site' CHECK (type IN ('job_site', 'delivery', 'meeting', 'leave', 'other')),
  project_id int REFERENCES project.project(id) ON DELETE SET NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  start_time time DEFAULT '08:00',
  end_time time DEFAULT '17:00',
  location text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_dates CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_event_tenant ON planning.event(tenant_id);
CREATE INDEX IF NOT EXISTS idx_event_dates ON planning.event(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_event_project ON planning.event(project_id);

-- Assignments (worker <-> event link)
CREATE TABLE IF NOT EXISTS planning.assignment (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  event_id int NOT NULL REFERENCES planning.event(id) ON DELETE CASCADE,
  worker_id int NOT NULL REFERENCES planning.worker(id) ON DELETE CASCADE,
  UNIQUE(event_id, worker_id)
);

CREATE INDEX IF NOT EXISTS idx_assignment_tenant ON planning.assignment(tenant_id);
CREATE INDEX IF NOT EXISTS idx_assignment_event ON planning.assignment(event_id);
CREATE INDEX IF NOT EXISTS idx_assignment_worker ON planning.assignment(worker_id);

-- Row Level Security
ALTER TABLE planning.worker ENABLE ROW LEVEL SECURITY;
ALTER TABLE planning.event ENABLE ROW LEVEL SECURITY;
ALTER TABLE planning.assignment ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON planning.worker;
CREATE POLICY tenant_isolation ON planning.worker
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON planning.event;
CREATE POLICY tenant_isolation ON planning.event
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON planning.assignment;
CREATE POLICY tenant_isolation ON planning.assignment
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Table grants: SELECT only (writes via SECURITY DEFINER functions)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA planning FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA planning TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA planning TO anon;
