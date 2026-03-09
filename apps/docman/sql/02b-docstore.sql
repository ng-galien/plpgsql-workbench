-- docstore: file index table (dependency for docman)
CREATE TABLE IF NOT EXISTS docstore.file (
  path text PRIMARY KEY,
  filename text,
  extension text,
  size_bytes bigint,
  content_hash text,
  mime_type text,
  fs_modified_at timestamptz,
  indexed_at timestamptz DEFAULT now()
);

GRANT SELECT ON ALL TABLES IN SCHEMA docstore TO web_anon;
