ALTER TABLE workbench.tenant_module ADD COLUMN IF NOT EXISTS nav_group TEXT NOT NULL DEFAULT 'main';
