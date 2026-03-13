CREATE OR REPLACE FUNCTION planning.post_affecter(p_evenement_id integer, p_intervenant_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO planning.affectation (evenement_id, intervenant_id)
  VALUES (p_evenement_id, p_intervenant_id)
  ON CONFLICT (evenement_id, intervenant_id) DO NOTHING;

  RETURN format('<template data-toast="success">%s</template><template data-redirect="%s"></template>',
    pgv.t('planning.toast_affecte'),
    pgv.call_ref('get_evenement', jsonb_build_object('p_id', p_evenement_id)));
END;
$function$;
