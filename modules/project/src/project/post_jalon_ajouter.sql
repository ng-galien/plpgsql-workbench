CREATE OR REPLACE FUNCTION project.post_jalon_ajouter(p_chantier_id integer, p_label text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_order int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_chantier_id AND statut IN ('preparation','execution')) THEN
    RAISE EXCEPTION 'Chantier introuvable ou non modifiable';
  END IF;
  SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_order
    FROM project.jalon WHERE chantier_id = p_chantier_id;
  INSERT INTO project.jalon (chantier_id, sort_order, label)
  VALUES (p_chantier_id, v_order, p_label);
  RETURN '<template data-toast="success">Jalon ajouté</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_chantier_id)) || '"></template>';
END;
$function$;
