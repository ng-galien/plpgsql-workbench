CREATE SCHEMA IF NOT EXISTS "plxdemo";

CREATE SCHEMA IF NOT EXISTS "plxdemo_ut";

CREATE SCHEMA IF NOT EXISTS "plxdemo_qa";

CREATE TABLE IF NOT EXISTS plxdemo.task (
  id serial PRIMARY KEY,
  rank int DEFAULT 0,
  note_id int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  data jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE plxdemo.task DROP CONSTRAINT IF EXISTS task_note_id_fkey;
ALTER TABLE plxdemo.task ADD CONSTRAINT task_note_id_fkey FOREIGN KEY (note_id) REFERENCES plxdemo.note(id);

GRANT USAGE ON SCHEMA plxdemo TO anon;
GRANT SELECT ON TABLE plxdemo.task TO anon;

CREATE TABLE IF NOT EXISTS plxdemo.note (
  id serial PRIMARY KEY,
  title text NOT NULL,
  body text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT USAGE ON SCHEMA plxdemo TO anon;
GRANT SELECT ON TABLE plxdemo.note TO anon;
