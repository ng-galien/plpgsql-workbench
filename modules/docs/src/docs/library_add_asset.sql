CREATE OR REPLACE FUNCTION docs.library_add_asset(p_library_id text, p_asset_id uuid, p_role text DEFAULT NULL::text, p_context text DEFAULT NULL::text, p_sort_order integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO docs.library_asset (library_id, asset_id, role, context, sort_order)
  VALUES (p_library_id, p_asset_id, p_role, p_context, p_sort_order)
  ON CONFLICT (library_id, asset_id) DO UPDATE SET
    role = EXCLUDED.role,
    context = EXCLUDED.context,
    sort_order = EXCLUDED.sort_order;
END;
$function$;
