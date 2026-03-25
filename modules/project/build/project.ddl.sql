-- project — DDL

CREATE SCHEMA IF NOT EXISTS project;
CREATE SCHEMA IF NOT EXISTS project_ut;
CREATE SCHEMA IF NOT EXISTS project_qa;

-- Project
CREATE TABLE IF NOT EXISTS project.project (
    id              SERIAL PRIMARY KEY,
    code            TEXT NOT NULL UNIQUE,
    client_id       INTEGER NOT NULL REFERENCES crm.client(id),
    estimate_id     INTEGER REFERENCES quote.devis(id),
    subject         TEXT NOT NULL,
    address         TEXT NOT NULL DEFAULT '',
    status          TEXT NOT NULL DEFAULT 'draft',
    start_date      DATE,
    due_date        DATE,
    end_date        DATE,
    notes           TEXT NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    tenant_id       TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT chk_project_status CHECK (status IN ('draft','active','review','closed'))
);

CREATE INDEX IF NOT EXISTS idx_project_client  ON project.project(client_id);
CREATE INDEX IF NOT EXISTS idx_project_status  ON project.project(status);
CREATE INDEX IF NOT EXISTS idx_project_estimate ON project.project(estimate_id);
CREATE INDEX IF NOT EXISTS idx_project_tenant  ON project.project(tenant_id);

-- Milestone
CREATE TABLE IF NOT EXISTS project.milestone (
    id              SERIAL PRIMARY KEY,
    project_id      INTEGER NOT NULL REFERENCES project.project(id) ON DELETE CASCADE,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    label           TEXT NOT NULL,
    progress_pct    NUMERIC(5,2) NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'todo',
    planned_date    DATE,
    actual_date     DATE,
    notes           TEXT NOT NULL DEFAULT '',
    tenant_id       TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT chk_milestone_status CHECK (status IN ('todo','in_progress','done')),
    CONSTRAINT chk_milestone_pct CHECK (progress_pct >= 0 AND progress_pct <= 100)
);

CREATE INDEX IF NOT EXISTS idx_milestone_project ON project.milestone(project_id);
CREATE INDEX IF NOT EXISTS idx_milestone_tenant   ON project.milestone(tenant_id);

-- Time entry
CREATE TABLE IF NOT EXISTS project.time_entry (
    id              SERIAL PRIMARY KEY,
    project_id      INTEGER NOT NULL REFERENCES project.project(id) ON DELETE CASCADE,
    entry_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    hours           NUMERIC(5,2) NOT NULL,
    description     TEXT NOT NULL DEFAULT '',
    tenant_id       TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT chk_time_entry_hours CHECK (hours > 0)
);

CREATE INDEX IF NOT EXISTS idx_time_entry_project_date ON project.time_entry(project_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_time_entry_tenant        ON project.time_entry(tenant_id);

-- Assignment
CREATE TABLE IF NOT EXISTS project.assignment (
    id              SERIAL PRIMARY KEY,
    project_id      INTEGER NOT NULL REFERENCES project.project(id) ON DELETE CASCADE,
    worker_name     TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT '',
    planned_hours   NUMERIC(7,2),
    tenant_id       TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true)
);

CREATE INDEX IF NOT EXISTS idx_assignment_project ON project.assignment(project_id);
CREATE INDEX IF NOT EXISTS idx_assignment_tenant   ON project.assignment(tenant_id);

-- Project note
CREATE TABLE IF NOT EXISTS project.project_note (
    id              SERIAL PRIMARY KEY,
    project_id      INTEGER NOT NULL REFERENCES project.project(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    tenant_id       TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true)
);

CREATE INDEX IF NOT EXISTS idx_project_note_project ON project.project_note(project_id);
CREATE INDEX IF NOT EXISTS idx_project_note_tenant   ON project.project_note(tenant_id);

-- RLS
ALTER TABLE project.project      ENABLE ROW LEVEL SECURITY;
ALTER TABLE project.milestone    ENABLE ROW LEVEL SECURITY;
ALTER TABLE project.time_entry   ENABLE ROW LEVEL SECURITY;
ALTER TABLE project.assignment   ENABLE ROW LEVEL SECURITY;
ALTER TABLE project.project_note ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'tenant_project') THEN
    CREATE POLICY tenant_project ON project.project USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'tenant_milestone') THEN
    CREATE POLICY tenant_milestone ON project.milestone USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'tenant_time_entry') THEN
    CREATE POLICY tenant_time_entry ON project.time_entry USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'tenant_assignment') THEN
    CREATE POLICY tenant_assignment ON project.assignment USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polname = 'tenant_project_note') THEN
    CREATE POLICY tenant_project_note ON project.project_note USING (tenant_id = current_setting('app.tenant_id', true));
  END IF;
END $$;

-- Grants: SELECT only, writes via SECURITY DEFINER functions
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA project FROM anon;
GRANT SELECT ON ALL TABLES IN SCHEMA project TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA project TO anon;
