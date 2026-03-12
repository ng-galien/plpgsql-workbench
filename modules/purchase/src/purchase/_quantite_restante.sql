CREATE OR REPLACE FUNCTION purchase._quantite_restante(p_ligne_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_commandee numeric;
  v_recue numeric;
BEGIN
  SELECT quantite INTO v_commandee FROM purchase.ligne WHERE id = p_ligne_id;
  SELECT coalesce(sum(quantite_recue), 0) INTO v_recue
    FROM purchase.reception_ligne WHERE ligne_id = p_ligne_id;
  RETURN v_commandee - v_recue;
END;
$function$;
