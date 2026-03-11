CREATE OR REPLACE FUNCTION cad.nest_group(p_child_group_id integer, p_parent_group_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_child_label text;
  v_parent_label text;
  v_ancestor_id int;
BEGIN
  SELECT label INTO v_child_label FROM cad.piece_group WHERE id = p_child_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe enfant #% introuvable', p_child_group_id;
  END IF;

  SELECT label INTO v_parent_label FROM cad.piece_group WHERE id = p_parent_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Groupe parent #% introuvable', p_parent_group_id;
  END IF;

  -- Détecter les cycles : remonter depuis le parent pour vérifier qu'on ne retombe pas sur l'enfant
  v_ancestor_id := p_parent_group_id;
  WHILE v_ancestor_id IS NOT NULL LOOP
    IF v_ancestor_id = p_child_group_id THEN
      RAISE EXCEPTION 'Cycle detecte: le groupe "%s" est un ancetre de "%s"', v_child_label, v_parent_label;
    END IF;
    SELECT parent_id INTO v_ancestor_id FROM cad.piece_group WHERE id = v_ancestor_id;
  END LOOP;

  -- Vérifier même dessin
  IF (SELECT drawing_id FROM cad.piece_group WHERE id = p_child_group_id)
     <> (SELECT drawing_id FROM cad.piece_group WHERE id = p_parent_group_id) THEN
    RAISE EXCEPTION 'Les groupes doivent appartenir au meme dessin';
  END IF;

  UPDATE cad.piece_group SET parent_id = p_parent_group_id WHERE id = p_child_group_id;

  RETURN format('nested: "%s" -> "%s"', v_child_label, v_parent_label);
END;
$function$;
