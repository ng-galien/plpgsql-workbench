CREATE OR REPLACE FUNCTION plxdemo_ut.test_health()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
BEGIN
  RETURN NEXT is(plxdemo.health()->>'name', 'plxdemo', 'assert line 17');
  RETURN NEXT is(plxdemo.health()->>'status', 'ok', 'assert line 18');
  RETURN NEXT is(plxdemo.health()->>'demo', 'crud', 'assert line 19');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n jsonb;
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_n := plxdemo.note_create(jsonb_build_object('title', 'Linked note', 'body', 'Task dependency'));
  v_c := plxdemo.task_create(jsonb_build_object('title', 'Buy milk', 'priority', 'high', 'done', false, 'rank', 3, 'note_id', (v_n->>'id')::int));
  RETURN NEXT is(v_c->>'title', 'Buy milk', 'assert line 4');
  RETURN NEXT is(v_c->>'priority', 'high', 'assert line 5');
  RETURN NEXT is(v_c->>'done', 'false', 'assert line 6');
  RETURN NEXT is(v_c->>'rank', '3', 'assert line 7');
  RETURN NEXT is(v_c->>'note_id', v_n->>'id', 'assert line 8');
  v_r := plxdemo.task_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Buy milk', 'assert line 11');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 12');
  v_u := plxdemo.task_update(v_c->>'id', jsonb_build_object('title', 'Buy oat milk'));
  RETURN NEXT is(v_u->>'title', 'Buy oat milk', 'assert line 15');
  v_d := plxdemo.task_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Buy oat milk', 'assert line 18');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_list()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n bigint;
BEGIN
  PERFORM plxdemo.task_create(jsonb_build_object('title', 'Alpha', 'priority', 'normal', 'done', false));
  PERFORM plxdemo.task_create(jsonb_build_object('title', 'Beta', 'priority', 'low', 'done', true));
  select count(*) INTO v_n from plxdemo.task_list();
  RETURN NEXT ok(v_n >= 2, 'assert line 24');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_note_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_c := plxdemo.note_create(jsonb_build_object('title', 'Draft note', 'body', 'Hello'));
  RETURN NEXT is(v_c->>'title', 'Draft note', 'assert line 3');
  RETURN NEXT is(v_c->>'body', 'Hello', 'assert line 4');
  v_r := plxdemo.note_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Draft note', 'assert line 7');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 8');
  v_u := plxdemo.note_update(v_c->>'id', jsonb_build_object('title', 'Updated note'));
  RETURN NEXT is(v_u->>'title', 'Updated note', 'assert line 11');
  v_d := plxdemo.note_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Updated note', 'assert line 14');
END;
$$;
