CREATE OR REPLACE FUNCTION plxdemo_ut.test_health()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
BEGIN
  RETURN NEXT is(plxdemo.health()->>'name', 'plxdemo', 'assert line 14');
  RETURN NEXT is(plxdemo.health()->>'status', 'ok', 'assert line 15');
  RETURN NEXT is(plxdemo.health()->>'demo', 'crud', 'assert line 16');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_c := plxdemo.task_create(jsonb_build_object('title', 'Buy milk', 'priority', 'high', 'done', false));
  RETURN NEXT is(v_c->>'title', 'Buy milk', 'assert line 3');
  RETURN NEXT is(v_c->>'priority', 'high', 'assert line 4');
  RETURN NEXT is(v_c->>'done', 'false', 'assert line 5');
  v_r := plxdemo.task_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Buy milk', 'assert line 8');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 9');
  v_u := plxdemo.task_update(v_c->>'id', jsonb_build_object('title', 'Buy oat milk'));
  RETURN NEXT is(v_u->>'title', 'Buy oat milk', 'assert line 12');
  v_d := plxdemo.task_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Buy oat milk', 'assert line 15');
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
  RETURN NEXT ok(v_n >= 2, 'assert line 21');
END;
$$;
