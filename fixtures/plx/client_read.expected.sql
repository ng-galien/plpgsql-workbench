CREATE OR REPLACE FUNCTION crm.client_read(p_id int)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_row crm.client;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  select * INTO v_row from crm.client where id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;
  IF v_row.status = 'active' THEN
    v_actions := v_actions || jsonb_build_object('action', 'archive');
  END IF;
  RETURN jsonb_build_object('data', row_to_json(v_row)::jsonb, 'uri', 'crm://client/' || v_row.id, 'actions', v_actions);
END;
$$;
