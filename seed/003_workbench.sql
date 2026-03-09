CREATE SCHEMA IF NOT EXISTS workbench;

CREATE TABLE IF NOT EXISTS workbench.toolbox (
  name TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS workbench.toolbox_tool (
  toolbox_name TEXT NOT NULL REFERENCES workbench.toolbox(name) ON DELETE CASCADE,
  tool_name TEXT NOT NULL,
  PRIMARY KEY (toolbox_name, tool_name)
);

CREATE TABLE IF NOT EXISTS workbench.tenant (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  toolbox_name TEXT NOT NULL REFERENCES workbench.toolbox(name),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workbench.config (
  app TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (app, key)
);
