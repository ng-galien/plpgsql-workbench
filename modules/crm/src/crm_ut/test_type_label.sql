CREATE OR REPLACE FUNCTION crm_ut.test_type_label()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(crm.type_label('individual'), 'Particulier', 'individual -> Particulier');
  RETURN NEXT is(crm.type_label('company'), 'Entreprise', 'company -> Entreprise');
  RETURN NEXT is(crm.type_label('call'), 'Appel', 'call -> Appel');
  RETURN NEXT is(crm.type_label('visit'), 'Visite', 'visit -> Visite');
  RETURN NEXT is(crm.type_label('email'), 'Courriel', 'email -> Courriel');
  RETURN NEXT is(crm.type_label('note'), 'Note', 'note -> Note');
END;
$function$;
