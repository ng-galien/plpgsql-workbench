CREATE OR REPLACE FUNCTION document.post_company_save(p_name text, p_siret text DEFAULT NULL::text, p_tva_intra text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_postal_code text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_mentions text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM document.set_company(p_name, p_siret, p_tva_intra, p_address, p_city, p_postal_code, p_phone, p_email, p_website, p_mentions);
  RETURN '<template data-toast="success">' || pgv.t('document.toast_company_saved') || '</template>'
      || '<template data-redirect="/company"></template>';
END;
$function$;
