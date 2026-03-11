CREATE OR REPLACE FUNCTION cad.rename_group(p_group_id integer, p_label text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_old text;
BEGIN
  SELECT label INTO v_old FROM cad.piece_group WHERE id = p_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe #% introuvable', p_group_id;
  END IF;

  UPDATE cad.piece_group SET label = p_label WHERE id = p_group_id;

  RETURN format('renamed: "%s" -> "%s"', v_old, p_label);
END;
$function$;
