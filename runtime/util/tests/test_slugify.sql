CREATE OR REPLACE FUNCTION util_ut.test_slugify()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Basic
  RETURN NEXT is(util.slugify('Hello World'), 'hello-world', 'basic: lowercase + space');

  -- Accents
  RETURN NEXT is(util.slugify('Gîte en Provence'), 'gite-en-provence', 'accents: î→i');
  RETURN NEXT is(util.slugify('DÉJÀ VU café crème'), 'deja-vu-cafe-creme', 'accents: é è ê');
  RETURN NEXT is(util.slugify('Cormorant Garamond'), 'cormorant-garamond', 'no accents: passthrough');

  -- Multipart
  RETURN NEXT is(util.slugify('restaurant', 'Menu Été'), 'restaurant-menu-ete', 'multipart: 2 parts');
  RETURN NEXT is(util.slugify('devis', 'Maison', 'Martin'), 'devis-maison-martin', 'multipart: 3 parts');

  -- Cleanup
  RETURN NEXT is(util.slugify('  Espaces  multiples  '), 'espaces-multiples', 'cleanup: multiple spaces');
  RETURN NEXT is(util.slugify('a--b--c'), 'a-b-c', 'cleanup: multiple dashes');

  -- Special chars
  RETURN NEXT is(util.slugify('L''Olivier & Fils'), 'l-olivier-fils', 'special: apostrophe + &');

  -- NULL handling
  RETURN NEXT is(util.slugify(NULL, 'test'), 'test', 'null: first part null');
  RETURN NEXT is(util.slugify('a', NULL, 'b'), 'a-b', 'null: middle part null');

  -- Empty
  RETURN NEXT is(util.slugify(''), '', 'empty: returns empty');
END;
$function$;
