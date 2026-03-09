-- App bootstrap: standalone pgView app for UI/UX validation
-- Zero dependency on docman/docstore — pure pgView patterns

-- App-local settings table (simple key/value)
CREATE TABLE IF NOT EXISTS app.setting (
  key   text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON app.setting TO web_anon;
