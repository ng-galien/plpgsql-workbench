-- uxlab: component showcase app

-- DDL -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS uxlab.setting (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS uxlab.item (
  id         serial PRIMARY KEY,
  name       text NOT NULL,
  status     text NOT NULL DEFAULT 'draft',
  created_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON uxlab.setting TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON uxlab.item TO web_anon;
GRANT USAGE ON SEQUENCE uxlab.item_id_seq TO web_anon;

INSERT INTO uxlab.item (name, status) VALUES
  ('Premier document', 'draft'),
  ('Facture Mars', 'classified'),
  ('Contrat bail', 'archived'),
  ('Releve bancaire', 'draft'),
  ('Attestation', 'classified');

-- Nav -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION uxlab.nav_items()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT '[
    {"href": "/", "label": "Dashboard"},
    {"href": "/atoms", "label": "Composants"},
    {"href": "/forms", "label": "Formulaires"},
    {"href": "/toast", "label": "Toasts"},
    {"href": "/errors", "label": "Erreurs"},
    {"href": "/settings", "label": "Config"}
  ]'::jsonb;
$$;

-- Pages ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION uxlab.page_dashboard()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_body text;
BEGIN
  v_body := pgv.grid(
    pgv.stat('Items', (SELECT count(*)::text FROM uxlab.item), 'total'),
    pgv.stat('Draft', (SELECT count(*)::text FROM uxlab.item WHERE status = 'draft'), 'a traiter'),
    pgv.stat('Classes', (SELECT count(*)::text FROM uxlab.item WHERE status = 'classified'), 'termine')
  );
  v_body := v_body || '<table><thead><tr><th>Nom</th><th>Statut</th><th>Date</th></tr></thead><tbody>';
  SELECT v_body || coalesce(string_agg(
    '<tr><td>' || pgv.esc(name) || '</td>'
    || '<td>' || pgv.badge(status,
        CASE status WHEN 'draft' THEN 'warning' WHEN 'classified' THEN 'success' WHEN 'archived' THEN 'default' ELSE 'info' END
       ) || '</td>'
    || '<td>' || to_char(created_at, 'DD/MM/YYYY') || '</td></tr>',
    '' ORDER BY created_at DESC
  ), '') INTO v_body FROM uxlab.item;
  v_body := v_body || '</tbody></table>';
  RETURN pgv.page('Dashboard', '/', uxlab.nav_items(), v_body);
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.page_atoms()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_body text;
BEGIN
  v_body :=
    -- Badges
    '<section><h4>pgv.badge</h4>'
    || '<p>'
    || pgv.badge('default') || ' '
    || pgv.badge('success', 'success') || ' '
    || pgv.badge('danger', 'danger') || ' '
    || pgv.badge('warning', 'warning') || ' '
    || pgv.badge('info', 'info') || ' '
    || pgv.badge('primary', 'primary')
    || '</p></section>'

    -- Stats
    || '<section><h4>pgv.stat + pgv.grid</h4>'
    || pgv.grid(
        pgv.stat('Utilisateurs', '1 234', '+12% ce mois'),
        pgv.stat('Revenu', pgv.money(42567.89), 'mensuel'),
        pgv.stat('Stockage', pgv.filesize(1073741824), 'utilise')
       )
    || '</section>'

    -- Cards
    || '<section><h4>pgv.card</h4>'
    || pgv.grid(
        pgv.card('Titre simple', '<p>Contenu de la carte.</p>'),
        pgv.card('Avec footer', '<p>Carte avec action.</p>',
          pgv.action('toast_success', 'Action', NULL, NULL, 'outline'))
       )
    || '</section>'

    -- Description list
    || '<section><h4>pgv.dl</h4>'
    || pgv.dl('Nom', 'Jean Dupont', 'Email', 'jean@example.com', 'Role', 'Admin', 'Statut', pgv.badge('actif', 'success'))
    || '</section>'

    -- Money + filesize
    || '<section><h4>pgv.money + pgv.filesize</h4>'
    || '<table><thead><tr><th>Montant</th><th>Taille</th></tr></thead><tbody>'
    || '<tr><td>' || pgv.money(0) || '</td><td>' || pgv.filesize(0) || '</td></tr>'
    || '<tr><td>' || pgv.money(1234.56) || '</td><td>' || pgv.filesize(1024) || '</td></tr>'
    || '<tr><td>' || pgv.money(99999.99) || '</td><td>' || pgv.filesize(5242880) || '</td></tr>'
    || '<tr><td>' || pgv.money(1000000) || '</td><td>' || pgv.filesize(1073741824) || '</td></tr>'
    || '</tbody></table></section>'

    -- Error display
    || '<section><h4>pgv.error</h4>'
    || pgv.error('404', 'Page non trouvee', 'Le chemin /exemple n''existe pas.', 'Verifiez l''URL.')
    || '</section>';

  RETURN pgv.page('Composants', '/atoms', uxlab.nav_items(), v_body);
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.page_forms()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_body text;
BEGIN
  v_body :=
    -- Simple form
    '<section><h4>Formulaire data-rpc</h4>'
    || '<form data-rpc="form_echo">'
    || pgv.input('p_name', 'text', 'Nom', NULL, true)
    || pgv.input('p_email', 'email', 'Email')
    || pgv.sel('p_role', 'Role', '["admin", "user", "viewer"]'::jsonb, 'user')
    || pgv.textarea('p_notes', 'Notes', 'Texte libre...')
    || '<button type="submit">Envoyer</button>'
    || '</form></section>'

    -- Action buttons
    || '<section><h4>Boutons data-rpc</h4>'
    || '<div class="grid">'
    || pgv.action('toast_success', 'Action simple')
    || pgv.action('toast_success', 'Avec confirmation', NULL, 'Etes-vous sur?')
    || pgv.action('toast_error', 'Action danger', NULL, NULL, 'danger')
    || pgv.action('toast_success', 'Outline', NULL, NULL, 'outline')
    || '</div></section>';

  RETURN pgv.page('Formulaires', '/forms', uxlab.nav_items(), v_body);
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.page_toast()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_body text;
BEGIN
  v_body :=
    '<section><h4>Toasts serveur (data-toast)</h4>'
    || '<p>Chaque bouton POST via data-rpc, le serveur retourne un template data-toast.</p>'
    || '<div class="grid">'
    || '<button data-rpc="toast_success">Toast succes</button>'
    || '<button data-rpc="toast_error" class="secondary">Toast erreur</button>'
    || '</div></section>'
    || '<section><h4>Erreur PostgREST (RAISE)</h4>'
    || '<p>Le serveur RAISE une exception. Le shell parse le JSON PostgREST et affiche un toast.</p>'
    || '<button data-rpc="toast_raise" class="contrast">Declencher RAISE</button>'
    || '</section>';
  RETURN pgv.page('Toasts', '/toast', uxlab.nav_items(), v_body);
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.page_errors()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_body text;
BEGIN
  v_body :=
    '<section><h4>Gestion des erreurs du routeur</h4>'
    || '<p>Le routeur attrape les exceptions et rend des pages d''erreur.</p>'
    || '<div class="grid">'
    || pgv.card('404', '<p>Page inexistante</p>', '<a href="/nexiste/pas">Tester 404</a>')
    || pgv.card('Erreur metier', '<p>RAISE EXCEPTION</p>', '<a href="/test/raise">Tester raise</a>')
    || pgv.card('Parametre invalide', '<p>UUID invalide</p>', '<a href="/test/bad-uuid">Tester UUID</a>')
    || '</div></section>';
  RETURN pgv.page('Erreurs', '/errors', uxlab.nav_items(), v_body);
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.page_settings()
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_root text; v_body text;
BEGIN
  SELECT value INTO v_root FROM uxlab.setting WHERE key = 'documentsRoot';
  v_body :=
    '<section><h4>Documents</h4>'
    || '<form data-rpc="save_settings">'
    || '<label>Repertoire racine'
    || '<div style="display:flex;gap:.5rem">'
    || '<input id="documentsRoot" name="p_documentsroot" type="text"'
    || ' value="' || coalesce(pgv.esc(v_root), '') || '"'
    || ' placeholder="/chemin/vers/documents" required style="margin-bottom:0">'
    || '<button type="button" class="outline" style="margin-bottom:0;white-space:nowrap"'
    || ' data-dialog="folder-picker"'
    || ' data-src="' || CASE WHEN v_root IS NOT NULL THEN '/api/browse?path=' || pgv.esc(v_root) ELSE '/api/browse' END || '"'
    || ' data-target="documentsRoot">Parcourir</button>'
    || '</div></label>'
    || '<small>Dossier contenant les documents a indexer</small>'
    || '<button type="submit" style="width:auto;margin-top:1rem">Enregistrer</button>'
    || '</form></section>'
    || '<section><h4>Systeme</h4>'
    || pgv.dl('Version', '0.1.0', 'PostgreSQL', version())
    || '</section>';
  RETURN pgv.page('Configuration', '/settings', uxlab.nav_items(), v_body);
END;
$$;

-- Actions -------------------------------------------------------------

CREATE OR REPLACE FUNCTION uxlab.save_settings(p_documentsroot text DEFAULT NULL)
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  IF p_documentsroot IS NOT NULL AND p_documentsroot <> '' THEN
    INSERT INTO uxlab.setting (key, value, updated_at)
    VALUES ('documentsRoot', p_documentsroot, now())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
  END IF;
  RETURN '<template data-toast="success">Configuration enregistree</template>'
      || '<template data-redirect="/settings"></template>';
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.toast_success()
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  RETURN '<template data-toast="success">Operation reussie</template>';
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.toast_error()
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  RETURN '<template data-toast="error">Echec de l''operation</template>';
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.toast_raise()
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Document introuvable dans la base'
    USING HINT = 'Verifiez que le document a bien ete indexe.';
END;
$$;

CREATE OR REPLACE FUNCTION uxlab.form_echo(p_name text DEFAULT '', p_email text DEFAULT '', p_role text DEFAULT '', p_notes text DEFAULT '')
RETURNS "text/html" LANGUAGE plpgsql AS $$
BEGIN
  RETURN '<template data-toast="success">Formulaire recu: ' || pgv.esc(p_name) || '</template>'
      || '<template data-redirect="/forms"></template>';
END;
$$;

-- Router --------------------------------------------------------------

CREATE OR REPLACE FUNCTION uxlab.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
RETURNS "text/html" LANGUAGE plpgsql AS $$
DECLARE v_detail text; v_hint text; v_dummy uuid;
BEGIN
  CASE
    WHEN p_path = '/'           THEN RETURN uxlab.page_dashboard();
    WHEN p_path = '/atoms'      THEN RETURN uxlab.page_atoms();
    WHEN p_path = '/forms'      THEN RETURN uxlab.page_forms();
    WHEN p_path = '/toast'      THEN RETURN uxlab.page_toast();
    WHEN p_path = '/errors'     THEN RETURN uxlab.page_errors();
    WHEN p_path = '/settings'   THEN RETURN uxlab.page_settings();
    WHEN p_path = '/test/raise' THEN
      RAISE EXCEPTION 'Ceci est une erreur metier volontaire'
        USING HINT = 'Le routeur attrape les exceptions et rend une page d''erreur.';
    WHEN p_path = '/test/bad-uuid' THEN
      v_dummy := p_path::uuid;
    ELSE
      PERFORM set_config('response.status', '404', true);
      RETURN pgv.page('404', p_path, uxlab.nav_items(),
        pgv.error('404', 'Page non trouvee', 'Le chemin ' || p_path || ' n''existe pas.'));
  END CASE;
EXCEPTION
  WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page('Erreur', p_path, uxlab.nav_items(), pgv.error('400', 'Erreur', v_detail, v_hint));
  WHEN invalid_text_representation THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page('Erreur', p_path, uxlab.nav_items(), pgv.error('400', 'Parametre invalide', v_detail));
  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('response.status', '500', true);
    RETURN pgv.page('Erreur', p_path, uxlab.nav_items(), pgv.error('500', 'Erreur interne', 'Une erreur inattendue est survenue.'));
END;
$$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA uxlab TO web_anon;
