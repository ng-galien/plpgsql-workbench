CREATE OR REPLACE FUNCTION plxdemo_ut.test_health()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
BEGIN
  RETURN NEXT is(plxdemo.health()->>'name', 'plxdemo', 'assert line 20');
  RETURN NEXT is(plxdemo.health()->>'status', 'ok', 'assert line 21');
  RETURN NEXT is(plxdemo.health()->>'demo', 'crud+validation+states+events', 'assert line 22');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_project_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_c := plxdemo.project_create(jsonb_build_object('name', 'Alpha', 'code', 'ALPHA', 'description', 'First project', 'budget', 10000));
  RETURN NEXT is(v_c->>'name', 'Alpha', 'assert line 3');
  RETURN NEXT is(v_c->>'code', 'ALPHA', 'assert line 4');
  RETURN NEXT is(v_c->>'status', 'draft', 'assert line 5');
  RETURN NEXT is((v_c->>'budget')::numeric, 10000::numeric, 'assert line 6');
  v_r := plxdemo.project_read(v_c->>'id');
  RETURN NEXT is(v_r->>'name', 'Alpha', 'assert line 9');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 10');
  v_u := plxdemo.project_update(v_c->>'id', jsonb_build_object('description', 'Updated desc'));
  RETURN NEXT is(v_u->>'description', 'Updated desc', 'assert line 13');
  RETURN NEXT is(v_u->>'code', 'ALPHA', 'assert line 14');
  v_d := plxdemo.project_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'name', 'Alpha', 'assert line 17');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_project_state_transitions()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_blocked boolean := false;
  v_u jsonb;
  v_a jsonb;
  v_kickoff_count bigint;
  v_co jsonb;
  v_ar jsonb;
BEGIN
  v_c := plxdemo.project_create(jsonb_build_object('name', 'Beta', 'code', 'BETA'));
  RETURN NEXT is(v_c->>'status', 'draft', 'assert line 21');
  BEGIN
    PERFORM plxdemo.project_activate(v_c->>'id');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  RETURN NEXT is(v_blocked, true, 'assert line 28');
  v_u := plxdemo.project_update(v_c->>'id', jsonb_build_object('budget', 5000, 'owner', 'Alice'));
  RETURN NEXT is((v_u->>'budget')::numeric, 5000::numeric, 'assert line 31');
  RETURN NEXT is(v_u->>'owner', 'Alice', 'assert line 32');
  v_a := plxdemo.project_activate(v_c->>'id');
  RETURN NEXT is(v_a->>'status', 'active', 'assert line 35');
  select count(*) INTO v_kickoff_count from plxdemo.task where project_id = (v_a->>'id')::int and payload->>'title' = 'Kickoff';
  RETURN NEXT is(v_kickoff_count, 1::bigint, 'assert line 38');
  v_co := plxdemo.project_complete(v_c->>'id');
  RETURN NEXT is(v_co->>'status', 'completed', 'assert line 41');
  v_ar := plxdemo.project_archive(v_c->>'id');
  RETURN NEXT is(v_ar->>'status', 'archived', 'assert line 44');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_project_soft_delete_hides_from_read()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
BEGIN
  v_c := plxdemo.project_create(jsonb_build_object('name', 'Soft', 'code', 'SOFTDEL'));
  PERFORM plxdemo.project_delete(v_c->>'id');
  v_r := plxdemo.project_read(v_c->>'id');
  RETURN NEXT is(v_r, NULL, 'assert line 50');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_project_list()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n bigint;
BEGIN
  PERFORM plxdemo.project_create(jsonb_build_object('name', 'Listed1', 'code', 'L1'));
  PERFORM plxdemo.project_create(jsonb_build_object('name', 'Listed2', 'code', 'L2'));
  select count(*) INTO v_n from plxdemo.project_list();
  RETURN NEXT ok(v_n >= 2, 'assert line 56');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_project_rejects_negative_budget()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_blocked boolean := false;
BEGIN
  BEGIN
    PERFORM plxdemo.project_create(jsonb_build_object('name', 'Invalid', 'code', 'INVALID', 'budget', -1));
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  RETURN NEXT is(v_blocked, true, 'assert line 64');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n jsonb;
  v_p jsonb;
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_n := plxdemo.note_create(jsonb_build_object('title', 'Linked note', 'body', 'Task dependency'));
  v_p := plxdemo.project_create(jsonb_build_object('name', 'TaskProj', 'code', 'TP'));
  v_c := plxdemo.task_create(jsonb_build_object('title', 'Buy milk', 'priority', 'high', 'done', false, 'rank', 3, 'note_id', (v_n->>'id')::int, 'project_id', (v_p->>'id')::int));
  RETURN NEXT is(v_c->>'title', 'Buy milk', 'assert line 5');
  RETURN NEXT is(v_c->>'priority', 'high', 'assert line 6');
  RETURN NEXT is(v_c->>'done', 'false', 'assert line 7');
  RETURN NEXT is(v_c->>'rank', '3', 'assert line 8');
  RETURN NEXT is(v_c->>'note_id', v_n->>'id', 'assert line 9');
  RETURN NEXT is(v_c->>'project_id', v_p->>'id', 'assert line 10');
  v_r := plxdemo.task_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Buy milk', 'assert line 13');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 14');
  v_u := plxdemo.task_update(v_c->>'id', jsonb_build_object('title', 'Buy oat milk'));
  RETURN NEXT is(v_u->>'title', 'Buy oat milk', 'assert line 17');
  v_d := plxdemo.task_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Buy oat milk', 'assert line 20');
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
  RETURN NEXT ok(v_n >= 2, 'assert line 26');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_rejects_invalid_priority()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_blocked boolean := false;
BEGIN
  BEGIN
    PERFORM plxdemo.task_create(jsonb_build_object('title', 'Broken', 'priority', 'urgent'));
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  RETURN NEXT is(v_blocked, true, 'assert line 34');
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
  v_u := plxdemo.note_update(v_c->>'id', jsonb_build_object('title', 'Updated note', 'pinned', true));
  RETURN NEXT is(v_u->>'title', 'Updated note', 'assert line 11');
  v_d := plxdemo.note_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Updated note', 'assert line 14');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_note_soft_delete_hides_from_list()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
BEGIN
  v_c := plxdemo.note_create(jsonb_build_object('title', 'Vanish'));
  PERFORM plxdemo.note_delete(v_c->>'id');
  v_r := plxdemo.note_read(v_c->>'id');
  RETURN NEXT is(v_r, NULL, 'assert line 20');
END;
$$;
