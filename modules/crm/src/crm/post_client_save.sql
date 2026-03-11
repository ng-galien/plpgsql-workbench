CREATE OR REPLACE FUNCTION crm.post_client_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_tags text[];
  v_name text;
BEGIN
  v_name := trim(p_data->>'name');
  IF v_name IS NULL OR v_name = '' THEN
    RETURN '<template data-toast="error">Le nom est obligatoire.</template>';
  END IF;

  IF p_data->>'tags' IS NOT NULL AND trim(p_data->>'tags') <> '' THEN
    SELECT array_agg(DISTINCT lower(trim(t)))
      INTO v_tags
      FROM unnest(string_to_array(p_data->>'tags', ',')) AS t
     WHERE trim(t) <> '';
  ELSE
    v_tags := '{}';
  END IF;

  IF p_data->>'id' IS NOT NULL AND p_data->>'id' <> '' THEN
    v_id := (p_data->>'id')::int;
    UPDATE crm.client SET
      type = COALESCE(p_data->>'type', type),
      name = v_name,
      email = NULLIF(trim(p_data->>'email'), ''),
      phone = NULLIF(trim(p_data->>'phone'), ''),
      address = NULLIF(trim(p_data->>'address'), ''),
      city = NULLIF(trim(p_data->>'city'), ''),
      postal_code = NULLIF(trim(p_data->>'postal_code'), ''),
      tier = COALESCE(NULLIF(p_data->>'tier', ''), tier),
      tags = v_tags,
      notes = COALESCE(p_data->>'notes', ''),
      active = COALESCE((p_data->>'active')::boolean, active)
    WHERE id = v_id;

    RETURN '<template data-toast="success">Client modifié.</template>'
        || '<template data-redirect="' || pgv.call_ref('get_client', jsonb_build_object('p_id', v_id)) || '"></template>';
  ELSE
    INSERT INTO crm.client (type, name, email, phone, address, city, postal_code, tier, tags, notes)
    VALUES (
      COALESCE(p_data->>'type', 'individual'),
      v_name,
      NULLIF(trim(p_data->>'email'), ''),
      NULLIF(trim(p_data->>'phone'), ''),
      NULLIF(trim(p_data->>'address'), ''),
      NULLIF(trim(p_data->>'city'), ''),
      NULLIF(trim(p_data->>'postal_code'), ''),
      COALESCE(NULLIF(p_data->>'tier', ''), 'standard'),
      v_tags,
      COALESCE(p_data->>'notes', '')
    ) RETURNING id INTO v_id;

    RETURN '<template data-toast="success">Client créé.</template>'
        || '<template data-redirect="' || pgv.call_ref('get_client', jsonb_build_object('p_id', v_id)) || '"></template>';
  END IF;
END;
$function$;
