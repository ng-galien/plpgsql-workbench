CREATE OR REPLACE FUNCTION purchase_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  RETURN NEXT ok(length(purchase.brand()) > 0, 'brand() returns text');
  RETURN NEXT ok(purchase.nav_items() IS NOT NULL, 'nav_items() returns jsonb');
  RETURN NEXT ok(length(purchase.get_index()) > 0, 'get_index() returns HTML');
  RETURN NEXT ok(length(purchase.get_commande()) > 0, 'get_commande() list returns HTML');
  RETURN NEXT ok(length(purchase.get_commande_form()) > 0, 'get_commande_form() returns HTML');
  RETURN NEXT ok(length(purchase.get_facture_fournisseur()) > 0, 'get_facture_fournisseur() list returns HTML');
  RETURN NEXT ok(length(purchase.get_index()) > 100, 'get_index() has stats + tabs');
  RETURN NEXT ok(purchase.get_index() LIKE '%Top fournisseurs%', 'get_index() has Top fournisseurs tab');

  -- get_bon_commande needs an existing commande
  PERFORM purchase_qa.clean();
  PERFORM purchase_qa.seed();
  DECLARE v_cid int;
  BEGIN
    SELECT id INTO v_cid FROM purchase.commande LIMIT 1;
    RETURN NEXT ok(length(purchase.get_bon_commande(v_cid)) > 0, 'get_bon_commande() returns HTML');
    RETURN NEXT ok(purchase.get_bon_commande(v_cid) LIKE '%pgv-print%', 'get_bon_commande() has print class');
  END;

  -- get_recapitulatif
  RETURN NEXT ok(length(purchase.get_recapitulatif()) > 0, 'get_recapitulatif() returns HTML');
  RETURN NEXT ok(purchase.get_recapitulatif() LIKE '%Récapitulatif achats%', 'get_recapitulatif() has title');

  -- get_article_prix (with non-existent article -> empty state)
  RETURN NEXT ok(length(purchase.get_article_prix(99999)) > 0, 'get_article_prix() returns HTML');
  RETURN NEXT ok(purchase.get_article_prix(99999) LIKE '%Aucun achat%', 'get_article_prix() empty state');

  PERFORM purchase_qa.clean();
END;
$function$;
