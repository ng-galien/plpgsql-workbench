CREATE OR REPLACE FUNCTION stock.get_mouvement_form(p_type text DEFAULT 'entree'::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_depot_options text;
  v_type_options text;
  v_body text;
  v_article_search text;
BEGIN
  -- Article via select_search
  v_article_search := pgv.select_search(
    'article_id', 'Article',
    'article_options',
    'Rechercher un article...'
  );

  -- Dépôts actifs
  v_depot_options := '<option value="">-- Dépôt --</option>';
  SELECT v_depot_options || string_agg(
    format('<option value="%s">%s</option>', d.id, pgv.esc(d.nom)),
    '' ORDER BY d.nom
  ) INTO v_depot_options
  FROM stock.depot d WHERE d.actif;

  -- Type
  v_type_options := format('<option value="entree"%s>Entrée</option>', CASE WHEN p_type = 'entree' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="sortie"%s>Sortie</option>', CASE WHEN p_type = 'sortie' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="transfert"%s>Transfert</option>', CASE WHEN p_type = 'transfert' THEN ' selected' ELSE '' END);
  v_type_options := v_type_options || format('<option value="inventaire"%s>Inventaire</option>', CASE WHEN p_type = 'inventaire' THEN ' selected' ELSE '' END);

  v_body := format('<form data-rpc="post_mouvement_save">
    <label>Type <select name="type" required>%s</select></label>
    %s
    <label>Dépôt <select name="depot_id" required>%s</select></label>
    <label>Quantité <input type="number" name="quantite" step="0.01" min="0.01" required></label>
    <label>Prix unitaire <input type="number" name="prix_unitaire" step="0.01" min="0"></label>
    <label>Dépôt destination (transfert) <select name="depot_destination_id">%s</select></label>
    <label>Référence doc <input type="text" name="reference" placeholder="N° BL, commande..."></label>
    <label>Notes <textarea name="notes"></textarea></label>
    <button type="submit">Enregistrer</button>
  </form>',
    v_type_options,
    v_article_search,
    v_depot_options,
    v_depot_options  -- same options for destination
  );

  RETURN v_body;
END;
$function$;
