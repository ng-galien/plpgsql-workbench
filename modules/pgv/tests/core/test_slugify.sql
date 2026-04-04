CREATE OR REPLACE FUNCTION pgv_ut.test_slugify()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Basic
  RETURN NEXT is(pgv.slugify('Hello World'), 'hello-world', 'basic: lowercase + space');

  -- Accents
  RETURN NEXT is(pgv.slugify('Gîte en Provence'), 'gite-en-provence', 'accents: î→i');
  RETURN NEXT is(pgv.slugify('DÉJÀ VU café crème'), 'deja-vu-cafe-creme', 'accents: é è ê');
  RETURN NEXT is(pgv.slugify('Cormorant Garamond'), 'cormorant-garamond', 'no accents: passthrough');

  -- Multipart
  RETURN NEXT is(pgv.slugify('restaurant', 'Menu Été'), 'restaurant-menu-ete', 'multipart: 2 parts');
  RETURN NEXT is(pgv.slugify('devis', 'Maison', 'Martin'), 'devis-maison-martin', 'multipart: 3 parts');

  -- Cleanup
  RETURN NEXT is(pgv.slugify('  Espaces  multiples  '), 'espaces-multiples', 'cleanup: multiple spaces');
  RETURN NEXT is(pgv.slugify('a--b--c'), 'a-b-c', 'cleanup: multiple dashes');

  -- Special chars
  RETURN NEXT is(pgv.slugify('L''Olivier & Fils'), 'l-olivier-fils', 'special: apostrophe + &');

  -- NULL handling
  RETURN NEXT is(pgv.slugify(NULL, 'test'), 'test', 'null: first part null');
  RETURN NEXT is(pgv.slugify('a', NULL, 'b'), 'a-b', 'null: middle part null');

  -- Empty
  RETURN NEXT is(pgv.slugify(''), '', 'empty: returns empty');
END;
$function$;
