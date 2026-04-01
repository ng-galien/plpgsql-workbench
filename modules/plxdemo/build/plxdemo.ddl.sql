CREATE SCHEMA IF NOT EXISTS "plxdemo";

CREATE SCHEMA IF NOT EXISTS "plxdemo_ut";

CREATE SCHEMA IF NOT EXISTS "plxdemo_qa";

CREATE TABLE IF NOT EXISTS plxdemo.task (
  id serial PRIMARY KEY,
  title text NOT NULL,
  description text,
  priority text DEFAULT 'normal',
  done boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT USAGE ON SCHEMA plxdemo TO anon;
GRANT SELECT ON TABLE plxdemo.task TO anon;
