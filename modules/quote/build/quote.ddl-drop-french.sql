-- Drop old French-named functions after English rename

-- Old helpers
DROP FUNCTION IF EXISTS quote._mentions_html();
DROP FUNCTION IF EXISTS quote._next_numero(text);
DROP FUNCTION IF EXISTS quote._statut_badge(text);

-- Old CRUD (devis_* with old composite type — table renamed, type follows)
DROP FUNCTION IF EXISTS quote.devis_list(text);
DROP FUNCTION IF EXISTS quote.devis_read(text);
DROP FUNCTION IF EXISTS quote.devis_create(quote.estimate);
DROP FUNCTION IF EXISTS quote.devis_update(quote.estimate);
DROP FUNCTION IF EXISTS quote.devis_delete(text);
DROP FUNCTION IF EXISTS quote.devis_view();

DROP FUNCTION IF EXISTS quote.facture_list(text);
DROP FUNCTION IF EXISTS quote.facture_read(text);
DROP FUNCTION IF EXISTS quote.facture_create(quote.invoice);
DROP FUNCTION IF EXISTS quote.facture_update(quote.invoice);
DROP FUNCTION IF EXISTS quote.facture_delete(text);
DROP FUNCTION IF EXISTS quote.facture_view();

-- Old legacy pgView functions (broken — reference renamed tables)
DROP FUNCTION IF EXISTS quote.get_devis(integer);
DROP FUNCTION IF EXISTS quote.get_devis_form(integer);
DROP FUNCTION IF EXISTS quote.get_facture(integer);
DROP FUNCTION IF EXISTS quote.get_facture_form(integer);
DROP FUNCTION IF EXISTS quote.get_index();

DROP FUNCTION IF EXISTS quote.post_devis_save(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_envoyer(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_accepter(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_refuser(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_supprimer(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_dupliquer(jsonb);
DROP FUNCTION IF EXISTS quote.post_devis_facturer(jsonb);
DROP FUNCTION IF EXISTS quote.post_facture_save(jsonb);
DROP FUNCTION IF EXISTS quote.post_facture_envoyer(jsonb);
DROP FUNCTION IF EXISTS quote.post_facture_payer(jsonb);
DROP FUNCTION IF EXISTS quote.post_facture_supprimer(jsonb);
DROP FUNCTION IF EXISTS quote.post_facture_relancer(jsonb);
DROP FUNCTION IF EXISTS quote.post_ligne_ajouter(jsonb);
DROP FUNCTION IF EXISTS quote.post_ligne_supprimer(jsonb);

-- Old test functions (broken)
DROP FUNCTION IF EXISTS quote_ut.test_devis_view_schema();
DROP FUNCTION IF EXISTS quote_ut.test_facture_view_schema();
DROP FUNCTION IF EXISTS quote_ut.test__next_numero();
DROP FUNCTION IF EXISTS quote_ut.test_next_numero();
DROP FUNCTION IF EXISTS quote_ut.test_article_search();
DROP FUNCTION IF EXISTS quote_ut.test_delete_constraints();
DROP FUNCTION IF EXISTS quote_ut.test_devis_facturer();
DROP FUNCTION IF EXISTS quote_ut.test_devis_lifecycle();
DROP FUNCTION IF EXISTS quote_ut.test_facture_lifecycle();
DROP FUNCTION IF EXISTS quote_ut.test_ligne_parent_check();
DROP FUNCTION IF EXISTS quote_ut.test_ligne_totals();
DROP FUNCTION IF EXISTS quote_ut.test_post_devis_dupliquer();
DROP FUNCTION IF EXISTS quote_ut.test_post_devis_facturer();
DROP FUNCTION IF EXISTS quote_ut.test_post_facture_relancer();
DROP FUNCTION IF EXISTS quote_ut.test_post_ligne_ajouter();

-- Old QA functions (broken)
DROP FUNCTION IF EXISTS quote_qa.seed();
DROP FUNCTION IF EXISTS quote_qa.clean();
