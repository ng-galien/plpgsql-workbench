CREATE OR REPLACE FUNCTION pgv_ut.test_card()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- Basic card
  v := pgv.card('Title', '<p>Body</p>');
  RETURN NEXT ok(v LIKE '%<article>%', 'has article tag');
  RETURN NEXT ok(v LIKE '%<header>Title</header>%', 'has header');
  RETURN NEXT ok(v LIKE '%<p>Body</p>%', 'has body');
  RETURN NEXT ok(v NOT LIKE '%<footer>%', 'no footer when NULL');

  -- Card with footer
  v := pgv.card('T', 'B', 'F');
  RETURN NEXT ok(v LIKE '%<footer>F</footer>%', 'has footer');

  -- Card without title
  v := pgv.card(NULL, 'B');
  RETURN NEXT ok(v NOT LIKE '%<header>%', 'no header when NULL');

  -- Markdown mode
  v := pgv.card('MD Card', '| A | B |', p_md := true);
  RETURN NEXT ok(v LIKE '%<md>%', 'md mode wraps in md tag');
  RETURN NEXT ok(v LIKE '%| A | B |%', 'md content preserved');
  RETURN NEXT ok(v LIKE '%</md>%', 'md closing tag');

  -- Default (no markdown)
  v := pgv.card('Plain', '| A | B |');
  RETURN NEXT ok(v NOT LIKE '%<md>%', 'default mode no md tag');

  RETURN;
END;
$function$;
