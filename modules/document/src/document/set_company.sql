CREATE OR REPLACE FUNCTION document.set_company(p_name text, p_siret text DEFAULT NULL::text, p_tva_intra text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_postal_code text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_mentions text DEFAULT NULL::text)
 RETURNS document.company
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_tid text := current_setting('app.tenant_id', true);
  v_row document.company;
BEGIN
  INSERT INTO document.company (tenant_id, name, siret, tva_intra, address, city, postal_code, phone, email, website, mentions)
  VALUES (v_tid, p_name, p_siret, p_tva_intra, p_address, p_city, p_postal_code, p_phone, p_email, p_website, p_mentions)
  ON CONFLICT (tenant_id) DO UPDATE SET
    name = EXCLUDED.name,
    siret = EXCLUDED.siret,
    tva_intra = EXCLUDED.tva_intra,
    address = EXCLUDED.address,
    city = EXCLUDED.city,
    postal_code = EXCLUDED.postal_code,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    website = EXCLUDED.website,
    mentions = EXCLUDED.mentions
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$function$;
