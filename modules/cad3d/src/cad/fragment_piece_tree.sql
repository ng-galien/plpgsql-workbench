CREATE OR REPLACE FUNCTION cad.fragment_piece_tree(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<div x-data="cadPieceTree" @cad-select.window="onViewerSelect($event.detail)" class="cad-tree">'
    || pgv.tree(cad._piece_tree_children(p_drawing_id), true)
    || '</div>';
END;
$function$;
