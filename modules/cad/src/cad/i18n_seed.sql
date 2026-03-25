CREATE OR REPLACE FUNCTION cad.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'cad.brand', 'CAD 3D'),
    ('fr', 'cad.nav_dessins', 'Dessins'),

    -- Common labels
    ('fr', 'cad.vue_2d', 'Vue 2D'),
    ('fr', 'cad.vue_3d', 'Vue 3D'),
    ('fr', 'cad.liste_debit', 'Liste de débit'),

    -- Stats
    ('fr', 'cad.stat_pieces', 'Pièces'),
    ('fr', 'cad.stat_groupes', 'Groupes'),
    ('fr', 'cad.stat_volume', 'Volume'),
    ('fr', 'cad.stat_echelle', 'Échelle'),
    ('fr', 'cad.stat_shapes', 'Shapes'),
    ('fr', 'cad.stat_calques', 'Calques'),
    ('fr', 'cad.stat_taille', 'Taille'),
    ('fr', 'cad.stat_total', 'Total dessins'),
    ('fr', 'cad.stat_dessins_2d', 'Dessins 2D'),
    ('fr', 'cad.stat_modeles_3d', 'Modèles 3D'),

    -- Index tabs
    ('fr', 'cad.tab_2d', 'Dessins 2D'),
    ('fr', 'cad.tab_3d', 'Modèles 3D'),
    ('fr', 'cad.col_nom', 'Nom'),
    ('fr', 'cad.col_taille_dessin', 'Taille'),
    ('fr', 'cad.col_echelle', 'Échelle'),
    ('fr', 'cad.col_elements', 'Éléments'),
    ('fr', 'cad.col_modifie', 'Modifié'),
    ('fr', 'cad.empty_no_2d', 'Aucun dessin 2D'),
    ('fr', 'cad.empty_no_3d', 'Aucun modèle 3D'),

    -- Wireframe tabs
    ('fr', 'cad.tab_face', 'Face (XZ)'),
    ('fr', 'cad.tab_dessus', 'Dessus (XY)'),
    ('fr', 'cad.tab_cote', 'Côté (YZ)'),

    -- Table headers (BOM)
    ('fr', 'cad.col_id', '#'),
    ('fr', 'cad.col_label', 'Label'),
    ('fr', 'cad.col_role', 'Rôle'),
    ('fr', 'cad.col_section', 'Section'),
    ('fr', 'cad.col_longueur', 'Longueur'),
    ('fr', 'cad.col_essence', 'Essence'),
    ('fr', 'cad.col_groupe', 'Groupe'),
    ('fr', 'cad.col_type', 'Type'),
    ('fr', 'cad.col_calque', 'Calque'),
    ('fr', 'cad.col_action', 'Action'),

    -- Index page
    ('fr', 'cad.btn_ouvrir', 'Ouvrir'),
    ('fr', 'cad.empty_no_drawing', 'Aucun dessin. Créez-en un ci-dessous.'),
    ('fr', 'cad.field_name', 'Nom du dessin'),
    ('fr', 'cad.btn_nouveau_dessin', 'Nouveau dessin'),
    ('fr', 'cad.field_dimension', 'Type'),
    ('fr', 'cad.dim_2d', 'Dessin 2D'),
    ('fr', 'cad.dim_3d', 'Modèle 3D'),

    -- Drawing page (2D)
    ('fr', 'cad.btn_suppr', 'Suppr.'),
    ('fr', 'cad.confirm_delete_shape', 'Supprimer cette shape ?'),
    ('fr', 'cad.title_add_shape', 'Ajouter une shape'),
    ('fr', 'cad.shape_line', 'Ligne'),
    ('fr', 'cad.shape_rect', 'Rectangle'),
    ('fr', 'cad.shape_circle', 'Cercle'),
    ('fr', 'cad.shape_text', 'Texte'),
    ('fr', 'cad.shape_dimension', 'Cote'),
    ('fr', 'cad.field_label', 'Label (optionnel)'),
    ('fr', 'cad.title_geometry', 'Géométrie (JSON)'),
    ('fr', 'cad.field_geometry', 'Géométrie JSON'),
    ('fr', 'cad.title_props', 'Propriétés bois (JSON)'),
    ('fr', 'cad.field_props', 'Props JSON'),
    ('fr', 'cad.btn_ajouter', 'Ajouter'),

    -- Error messages
    ('fr', 'cad.err_not_found', 'Dessin non trouvé'),
    ('fr', 'cad.err_not_found_detail', 'Le dessin #%s n''existe pas.'),
    ('fr', 'cad.err_name_required', 'Nom requis'),
    ('fr', 'cad.err_layer_type_required', 'Calque et type requis'),
    ('fr', 'cad.err_geometry_invalid', 'Géométrie JSON invalide'),
    ('fr', 'cad.err_props_invalid', 'Props JSON invalides'),
    ('fr', 'cad.err_shape_id_required', 'shape_id requis'),

    -- Toast messages
    ('fr', 'cad.toast_shape_added', 'Shape #%s ajoutée'),
    ('fr', 'cad.toast_shape_deleted', 'Shape #%s supprimée'),

    -- Entity / _view()
    ('fr', 'cad.entity_drawing', 'Dessin'),
    ('fr', 'cad.field_scale', 'Échelle'),
    ('fr', 'cad.field_unit', 'Unité'),
    ('fr', 'cad.field_width', 'Largeur'),
    ('fr', 'cad.field_height', 'Hauteur'),
    ('fr', 'cad.section_general', 'Général'),
    ('fr', 'cad.section_canvas', 'Canvas'),
    ('fr', 'cad.action_delete', 'Supprimer'),
    ('fr', 'cad.action_duplicate', 'Dupliquer'),
    ('fr', 'cad.action_export_bom', 'Exporter nomenclature'),
    ('fr', 'cad.confirm_delete', 'Supprimer ce dessin et tout son contenu ?'),
    ('fr', 'cad.rel_shapes', 'Shapes'),
    ('fr', 'cad.rel_pieces', 'Pièces')

  ON CONFLICT DO NOTHING;
END;
$function$;
