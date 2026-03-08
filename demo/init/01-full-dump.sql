--
-- PostgreSQL database dump
--

\restrict FLonl5zPFy3Rb4ckbvJiHZB5VZo3LiAld99JVVLhVGVLOIKjjjKUEJEgtjnq4jW

-- Dumped from database version 16.11 (Debian 16.11-1.pgdg12+1)
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: organic; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA organic;


--
-- Name: shop; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA shop;


--
-- Name: shop_ut; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA shop_ut;


--
-- Name: pgtap; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA public;


--
-- Name: EXTENSION pgtap; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgtap IS 'Unit testing for PostgreSQL';


--
-- Name: plpgsql_check; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql_check WITH SCHEMA public;


--
-- Name: EXTENSION plpgsql_check; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql_check IS 'extended check for plpgsql functions';


--
-- Name: agent_role; Type: TYPE; Schema: organic; Owner: -
--

CREATE TYPE organic.agent_role AS ENUM (
    'owner',
    'lead',
    'craftsman',
    'reviewer'
);


--
-- Name: entity_kind; Type: TYPE; Schema: organic; Owner: -
--

CREATE TYPE organic.entity_kind AS ENUM (
    'capability',
    'pattern',
    'module',
    'domain'
);


--
-- Name: intent_state; Type: TYPE; Schema: organic; Owner: -
--

CREATE TYPE organic.intent_state AS ENUM (
    'declared',
    'engaged',
    'done',
    'canceled'
);


--
-- Name: task_state; Type: TYPE; Schema: organic; Owner: -
--

CREATE TYPE organic.task_state AS ENUM (
    'pending',
    'assigned',
    'in_progress',
    'done',
    'blocked',
    'canceled'
);


--
-- Name: log_event(text, text, text, jsonb, text); Type: FUNCTION; Schema: organic; Owner: -
--

CREATE FUNCTION organic.log_event(p_entity_type text, p_entity_id text, p_action text, p_payload jsonb DEFAULT NULL::jsonb, p_actor text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO organic.event (entity_type, entity_id, action, payload, actor)
  VALUES (p_entity_type, p_entity_id, p_action, p_payload, p_actor)
  RETURNING id INTO v_id;

  PERFORM pg_notify('organic', json_build_object(
    'event', p_action,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'payload', p_payload
  )::text);

  RETURN v_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: intent; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.intent (
    id text NOT NULL,
    name text NOT NULL,
    description text,
    state organic.intent_state DEFAULT 'declared'::organic.intent_state NOT NULL,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: transition_intent(text, organic.intent_state, text); Type: FUNCTION; Schema: organic; Owner: -
--

CREATE FUNCTION organic.transition_intent(p_intent_id text, p_new_state organic.intent_state, p_actor text DEFAULT NULL::text) RETURNS organic.intent
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_old_state organic.intent_state;
  v_intent organic.intent;
  v_allowed boolean;
BEGIN
  SELECT state INTO v_old_state FROM organic.intent WHERE id = p_intent_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent % not found', p_intent_id;
  END IF;

  v_allowed := CASE
    WHEN p_new_state = 'canceled' THEN true
    WHEN v_old_state = 'declared' AND p_new_state = 'engaged' THEN true
    WHEN v_old_state = 'engaged' AND p_new_state = 'done' THEN true
    ELSE false
  END;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'invalid transition: % → %', v_old_state, p_new_state;
  END IF;

  UPDATE organic.intent
  SET state = p_new_state, updated_at = now()
  WHERE id = p_intent_id
  RETURNING * INTO v_intent;

  PERFORM organic.log_event('intent', p_intent_id, 'transition',
    json_build_object('from', v_old_state, 'to', p_new_state)::jsonb, p_actor);

  RETURN v_intent;
END;
$$;


--
-- Name: task; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.task (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    intent_id text NOT NULL,
    name text NOT NULL,
    description text,
    state organic.task_state DEFAULT 'pending'::organic.task_state NOT NULL,
    assigned_to text,
    result jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: transition_task(uuid, organic.task_state, text, jsonb); Type: FUNCTION; Schema: organic; Owner: -
--

CREATE FUNCTION organic.transition_task(p_task_id uuid, p_new_state organic.task_state, p_actor text DEFAULT NULL::text, p_result jsonb DEFAULT NULL::jsonb) RETURNS organic.task
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_old_state organic.task_state;
  v_task organic.task;
  v_allowed boolean;
  v_pending_count int;
BEGIN
  SELECT state INTO v_old_state FROM organic.task WHERE id = p_task_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'task % not found', p_task_id;
  END IF;

  v_allowed := CASE
    WHEN p_new_state = 'canceled' THEN true
    WHEN v_old_state = 'pending' AND p_new_state = 'assigned' THEN true
    WHEN v_old_state = 'assigned' AND p_new_state = 'in_progress' THEN true
    WHEN v_old_state = 'in_progress' AND p_new_state IN ('done', 'blocked') THEN true
    WHEN v_old_state = 'assigned' AND p_new_state IN ('done', 'blocked') THEN true
    WHEN v_old_state = 'blocked' AND p_new_state = 'assigned' THEN true
    ELSE false
  END;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'invalid transition: % → %', v_old_state, p_new_state;
  END IF;

  UPDATE organic.task
  SET state = p_new_state,
      result = COALESCE(p_result, result),
      updated_at = now()
  WHERE id = p_task_id
  RETURNING * INTO v_task;

  PERFORM organic.log_event('task', p_task_id::text, 'transition',
    json_build_object('from', v_old_state, 'to', p_new_state, 'intent', v_task.intent_id)::jsonb, p_actor);

  -- auto-complete intent when all tasks are done
  IF p_new_state = 'done' THEN
    SELECT count(*) INTO v_pending_count
    FROM organic.task
    WHERE intent_id = v_task.intent_id
      AND state NOT IN ('done', 'canceled');

    IF v_pending_count = 0 THEN
      PERFORM organic.transition_intent(v_task.intent_id, 'done', p_actor);
    END IF;
  END IF;

  RETURN v_task;
END;
$$;


--
-- Name: trg_set_updated_at(); Type: FUNCTION; Schema: organic; Owner: -
--

CREATE FUNCTION organic.trg_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


--
-- Name: trg_task_assigned(); Type: FUNCTION; Schema: organic; Owner: -
--

CREATE FUNCTION organic.trg_task_assigned() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.assigned_to IS NOT NULL AND (OLD.assigned_to IS DISTINCT FROM NEW.assigned_to) THEN
    NEW.state := 'assigned';
    NEW.updated_at := now();

    PERFORM organic.log_event('task', NEW.id::text, 'assigned',
      json_build_object('agent', NEW.assigned_to, 'intent', NEW.intent_id)::jsonb, NEW.assigned_to);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: apply_discount(text, numeric, integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.apply_discount(p_code text, p_subtotal numeric, p_item_count integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_disc shop.discounts;
  v_amount numeric := 0;
  v_free_items integer;
BEGIN
  SELECT * INTO v_disc FROM shop.discounts WHERE code = p_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'discount code "%" not found', p_code;
  END IF;

  IF NOT v_disc.active THEN
    RAISE EXCEPTION 'discount code "%" is inactive', p_code;
  END IF;

  IF v_disc.expires_at IS NOT NULL AND v_disc.expires_at < now() THEN
    RAISE EXCEPTION 'discount code "%" has expired', p_code;
  END IF;

  IF p_subtotal < v_disc.min_order THEN
    RAISE EXCEPTION 'minimum order % required for discount "%"', v_disc.min_order, p_code;
  END IF;

  CASE v_disc.kind
    WHEN 'percentage' THEN
      v_amount := ROUND(p_subtotal * v_disc.value / 100, 2);
    WHEN 'fixed' THEN
      v_amount := LEAST(v_disc.value, p_subtotal);
    WHEN 'buy_x_get_y' THEN
      IF p_item_count >= v_disc.buy_x THEN
        v_free_items := (p_item_count / v_disc.buy_x) * v_disc.get_y_free;
        v_amount := ROUND(v_free_items * (p_subtotal / p_item_count), 2);
      END IF;
  END CASE;

  RETURN v_amount;
END;
$$;


--
-- Name: cancel_order(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.cancel_order(p_order_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_order shop.orders;
  v_item record;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'order % not found', p_order_id;
  END IF;

  IF v_order.status = 'cancelled' THEN
    RETURN false;  -- already cancelled, idempotent
  END IF;

  IF v_order.status = 'shipped' THEN
    RAISE EXCEPTION 'cannot cancel shipped order %', p_order_id;
  END IF;

  -- Restore stock for each item
  FOR v_item IN
    SELECT product_id, quantity FROM shop.order_items WHERE order_id = p_order_id
  LOOP
    UPDATE shop.products SET stock = stock + v_item.quantity WHERE id = v_item.product_id;
  END LOOP;

  UPDATE shop.orders SET status = 'cancelled' WHERE id = p_order_id;
  RETURN true;
END;
$$;


--
-- Name: customer_tier(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.customer_tier(p_customer_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_total numeric;
BEGIN
  SELECT COALESCE(SUM(total), 0) INTO v_total
  FROM shop.orders
  WHERE customer_id = p_customer_id AND status != 'cancelled';

  RETURN CASE
    WHEN v_total >= 5000 THEN 'platinum'
    WHEN v_total >= 2000 THEN 'gold'
    WHEN v_total >= 500  THEN 'silver'
    ELSE 'bronze'
  END;
END;
$$;


--
-- Name: esc(text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.esc(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT replace(replace(replace(replace(
    COALESCE(p_text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;


--
-- Name: get_catalog(text, boolean); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.get_catalog(p_search text DEFAULT NULL::text, p_in_stock_only boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'products', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'price', p.price,
        'stock', p.stock,
        'available', p.stock > 0
      ) ORDER BY p.name
    ), '[]'::jsonb),
    'total', count(*),
    'in_stock', count(*) FILTER (WHERE p.stock > 0)
  ) INTO v_result
  FROM shop.products p
  WHERE (p_search IS NULL OR p.name ILIKE '%' || p_search || '%')
    AND (NOT p_in_stock_only OR p.stock > 0);

  RETURN v_result;
END;
$$;


--
-- Name: get_customer_dashboard(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.get_customer_dashboard(p_customer_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_customer shop.customers;
  v_tier text;
  v_stats jsonb;
  v_recent_orders jsonb;
BEGIN
  SELECT * INTO v_customer FROM shop.customers WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', format('customer %s not found', p_customer_id));
  END IF;

  v_tier := shop.customer_tier(p_customer_id);

  -- Aggregate stats
  SELECT jsonb_build_object(
    'total_orders', count(*),
    'total_spent', COALESCE(sum(total), 0),
    'avg_order', COALESCE(round(avg(total), 2), 0),
    'cancelled', count(*) FILTER (WHERE status = 'cancelled')
  ) INTO v_stats
  FROM shop.orders WHERE customer_id = p_customer_id;

  -- Last 5 orders
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'order_id', o.id,
      'status', o.status,
      'total', o.total,
      'items', (SELECT count(*) FROM shop.order_items WHERE order_id = o.id),
      'created_at', o.created_at
    ) ORDER BY o.created_at DESC
  ), '[]'::jsonb) INTO v_recent_orders
  FROM (
    SELECT * FROM shop.orders
    WHERE customer_id = p_customer_id
    ORDER BY created_at DESC LIMIT 5
  ) o;

  RETURN jsonb_build_object(
    'customer', jsonb_build_object(
      'id', v_customer.id,
      'name', v_customer.name,
      'email', v_customer.email,
      'member_since', v_customer.created_at
    ),
    'tier', v_tier,
    'tier_discount', CASE v_tier
      WHEN 'platinum' THEN 10
      WHEN 'gold' THEN 5
      WHEN 'silver' THEN 2
      ELSE 0
    END,
    'stats', v_stats,
    'recent_orders', v_recent_orders
  );
END;
$$;


--
-- Name: get_order_details(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.get_order_details(p_order_id integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_order shop.orders;
  v_items jsonb;
  v_customer jsonb;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', format('order %s not found', p_order_id));
  END IF;

  -- Customer info
  SELECT jsonb_build_object(
    'id', c.id, 'name', c.name, 'email', c.email,
    'tier', shop.customer_tier(c.id)
  ) INTO v_customer
  FROM shop.customers c WHERE c.id = v_order.customer_id;

  -- Line items with product names
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'product', p.name,
      'quantity', oi.quantity,
      'unit_price', oi.unit_price,
      'subtotal', oi.subtotal
    ) ORDER BY oi.id
  ), '[]'::jsonb) INTO v_items
  FROM shop.order_items oi
  JOIN shop.products p ON p.id = oi.product_id
  WHERE oi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'order_id', v_order.id,
    'status', v_order.status,
    'customer', v_customer,
    'items', v_items,
    'subtotal', v_order.subtotal,
    'discount_code', v_order.discount_code,
    'discount_amount', v_order.discount_amount,
    'total', v_order.total,
    'created_at', v_order.created_at
  );
END;
$$;


--
-- Name: page(text, jsonb); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_content text;
BEGIN
  CASE
    -- Pages
    WHEN p_path = '/' THEN
      v_content := shop.pgv_dashboard();
    WHEN p_path = '/products' THEN
      v_content := shop.pgv_products();
    WHEN p_path ~ '^/products/(\d+)$' THEN
      v_content := shop.pgv_product(shop.path_segment(p_path, 2)::integer);
    WHEN p_path = '/customers' THEN
      v_content := shop.pgv_customers();
    WHEN p_path ~ '^/customers/(\d+)$' THEN
      v_content := shop.pgv_customer(shop.path_segment(p_path, 2)::integer);
    WHEN p_path = '/discounts' THEN
      v_content := shop.pgv_discounts();
    WHEN p_path = '/graph' THEN
      v_content := shop.pgv_graph();
    WHEN p_path = '/orders' THEN
      v_content := shop.pgv_orders();
    WHEN p_path = '/orders/new' THEN
      v_content := shop.pgv_order_form();
    WHEN p_path ~ '^/orders/(\d+)$' THEN
      v_content := shop.pgv_order(shop.path_segment(p_path, 2)::integer);

    -- Actions
    WHEN p_path = '/orders/place' THEN
      v_content := shop.pgv_place_order(p_body);
    WHEN p_path ~ '^/orders/(\d+)/cancel$' THEN
      v_content := shop.pgv_cancel_order(shop.path_segment(p_path, 2)::integer);

    -- 404
    ELSE
      v_content := '<main class="container"><article>'
        || '<header>Not Found</header>'
        || '<p>' || shop.esc(p_path) || '</p>'
        || '<footer><a href="/" role="button" class="outline">Go home</a></footer>'
        || '</article></main>';
  END CASE;

  -- Redirects pass through without nav
  IF v_content LIKE '<!-- redirect:%' THEN
    RETURN v_content;
  END IF;

  RETURN shop.pgv_nav(p_path) || v_content;
END;
$_$;


--
-- Name: path_segment(text, integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.path_segment(p_path text, p_pos integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT (string_to_array(trim(LEADING '/' FROM p_path), '/'))[p_pos];
$$;


--
-- Name: pgv_badge(text, text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_badge(p_text text, p_variant text DEFAULT 'default'::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT format(
    '<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.85em;font-weight:500;%s">%s</span>',
    CASE p_variant
      WHEN 'success'  THEN 'background:#d4edda;color:#155724'
      WHEN 'danger'   THEN 'background:#f8d7da;color:#721c24'
      WHEN 'warning'  THEN 'background:#fff3cd;color:#856404'
      WHEN 'info'     THEN 'background:#cce5ff;color:#004085'
      WHEN 'platinum' THEN 'background:linear-gradient(135deg,#e5e4e2,#b8b8b8);color:#333'
      WHEN 'gold'     THEN 'background:linear-gradient(135deg,#ffd700,#daa520);color:#333'
      WHEN 'silver'   THEN 'background:linear-gradient(135deg,#c0c0c0,#a0a0a0);color:#333'
      WHEN 'bronze'   THEN 'background:linear-gradient(135deg,#cd7f32,#a0522d);color:#fff'
      ELSE                  'background:#e2e3e5;color:#383d41'
    END,
    p_text
  );
$$;


--
-- Name: pgv_cancel_order(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_cancel_order(p_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM shop.cancel_order(p_id);
  RETURN '<!-- redirect:/orders/' || p_id || ' -->';
EXCEPTION WHEN OTHERS THEN
  RETURN '<main class="container"><article>'
    || '<header>Error</header>'
    || '<p>' || shop.esc(SQLERRM) || '</p>'
    || '<footer><a href="/orders/' || p_id || '" role="button" class="outline">Back</a></footer>'
    || '</article></main>';
END;
$$;


--
-- Name: pgv_customer(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_customer(p_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html  text;
  v_md    text;
  v_cust  shop.customers;
  v_tier  text;
  v_count bigint;
  v_spent numeric;
  r       record;
BEGIN
  SELECT * INTO v_cust FROM shop.customers WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Customer not found.</p><footer><a href="/customers">Back</a></footer></article></main>';
  END IF;

  v_tier := shop.customer_tier(p_id);
  SELECT count(*), COALESCE(sum(total), 0)
    INTO v_count, v_spent
    FROM shop.orders WHERE customer_id = p_id AND status != 'cancelled';

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>%s</h2><p>%s customer</p></hgroup>',
    shop.esc(v_cust.name), shop.pgv_tier(v_tier));

  -- Info + Stats side by side
  v_html := v_html || '<div class="grid"><article><dl>';
  v_html := v_html || format('<dt>Email</dt><dd>%s</dd>', shop.esc(v_cust.email));
  v_html := v_html || format('<dt>Member since</dt><dd>%s</dd>', to_char(v_cust.created_at, 'YYYY-MM-DD'));
  v_html := v_html || format('<dt>Tier discount</dt><dd>%s%%</dd>',
    CASE v_tier WHEN 'platinum' THEN 10 WHEN 'gold' THEN 5 WHEN 'silver' THEN 2 ELSE 0 END);
  v_html := v_html || '</dl></article>';

  v_html := v_html || '<article style="text-align:center"><dl>';
  v_html := v_html || format('<dt>Orders</dt><dd><strong>%s</strong></dd>', v_count);
  v_html := v_html || format('<dt>Total spent</dt><dd><strong>%s</strong></dd>', shop.pgv_money(v_spent));
  v_html := v_html || '</dl></article></div>';

  -- Orders (Markdown)
  v_html := v_html || '<h3>Orders</h3>';
  v_md := E'| # | Status | Total | Date |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, o.status, o.total, to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o WHERE o.customer_id = p_id ORDER BY o.created_at DESC
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s |\n',
      r.id, r.id, shop.pgv_status(r.status), shop.pgv_money(r.total), r.dt);
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  v_html := v_html || '<a href="/customers" role="button" class="outline">Back to customers</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_customers(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_customers() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Customers</h2><p>All registered customers</p></hgroup>';

  v_md := E'| Name | Email | Tier | Since |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT c.*, shop.customer_tier(c.id) AS tier,
           to_char(c.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.customers c ORDER BY c.name
  LOOP
    v_md := v_md || format(E'| <a href="/customers/%s">%s</a> | %s | %s | %s |\n',
      r.id, shop.esc(r.name), shop.esc(r.email),
      shop.pgv_tier(r.tier), r.dt);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_dashboard(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_dashboard() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_customers bigint;
  v_products  bigint;
  v_orders    bigint;
  v_revenue   numeric;
  v_html      text;
  v_md        text;
  r           record;
BEGIN
  SELECT count(*) INTO v_customers FROM shop.customers;
  SELECT count(*) INTO v_products  FROM shop.products;
  SELECT count(*), COALESCE(sum(total), 0)
    INTO v_orders, v_revenue
    FROM shop.orders WHERE status != 'cancelled';

  v_html := '<main class="container"><h2>Dashboard</h2>';

  -- Stats grid
  v_html := v_html || '<div class="grid">';
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Customers</small></article>', v_customers);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Products</small></article>', v_products);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Orders</small></article>', v_orders);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Revenue</small></article>', shop.pgv_money(v_revenue));
  v_html := v_html || '</div>';

  -- Recent orders
  v_html := v_html || '<h3>Recent Orders</h3>';
  v_md := E'| # | Customer | Status | Total | Date |\n| --- | --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC LIMIT 10
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s | %s |\n',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      shop.pgv_money(r.total), r.dt);
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  -- Quick stats side by side
  v_html := v_html || '<div class="grid">';

  -- Top Products
  v_md := E'| Product | Sold |\n| --- | --- |\n';
  FOR r IN
    SELECT p.name, sum(oi.quantity) AS sold
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    JOIN shop.orders o ON o.id = oi.order_id AND o.status != 'cancelled'
    GROUP BY p.name ORDER BY sold DESC LIMIT 5
  LOOP
    v_md := v_md || format(E'| %s | %s sold |\n', shop.esc(r.name), r.sold);
  END LOOP;
  v_html := v_html || '<article><h4>Top Products</h4><md>' || v_md || '</md></article>';

  -- Low Stock
  v_md := E'| Product | Stock |\n| --- | --- |\n';
  FOR r IN
    SELECT name, stock FROM shop.products
    WHERE stock < 20 ORDER BY stock ASC LIMIT 5
  LOOP
    v_md := v_md || format(E'| %s | %s |\n',
      shop.esc(r.name),
      CASE WHEN r.stock = 0 THEN shop.pgv_badge('Out', 'danger')
           ELSE shop.pgv_badge(r.stock || ' left', 'warning') END);
  END LOOP;
  v_html := v_html || '<article><h4>Low Stock</h4><md>' || v_md || '</md></article>';

  v_html := v_html || '</div></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_discounts(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_discounts() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  r shop.discounts;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Discounts</h2><p>Available discount codes</p></hgroup>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>Code</th><th>Type</th><th>Value</th><th>Min Order</th><th>Status</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN SELECT * FROM shop.discounts ORDER BY active DESC, code
  LOOP
    v_html := v_html || format(
      '<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      shop.esc(r.code),
      CASE r.kind
        WHEN 'percentage' THEN shop.pgv_badge('%% off', 'info')
        WHEN 'fixed' THEN shop.pgv_badge('fixed', 'warning')
        WHEN 'buy_x_get_y' THEN shop.pgv_badge('buy X get Y', 'success')
      END,
      CASE r.kind
        WHEN 'percentage' THEN r.value || '%%'
        WHEN 'fixed' THEN shop.pgv_money(r.value)
        WHEN 'buy_x_get_y' THEN format('Buy %s get %s free', r.buy_x, r.get_y_free)
      END,
      CASE WHEN r.min_order > 0 THEN shop.pgv_money(r.min_order) ELSE '-' END,
      CASE WHEN r.active THEN shop.pgv_badge('active', 'success')
           ELSE shop.pgv_badge('inactive', 'danger') END
    );
  END LOOP;

  v_html := v_html || '</tbody></table></figure></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_graph(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_graph() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  v_mermaid text;
  r record;
BEGIN
  v_mermaid := 'graph LR' || chr(10);

  -- Router
  v_mermaid := v_mermaid || '  subgraph s_router["Router"]' || chr(10);
  v_mermaid := v_mermaid || '    fn_page["page"]' || chr(10);
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Pages
  v_mermaid := v_mermaid || '  subgraph s_pages["Pages"]' || chr(10);
  FOR r IN
    SELECT p.proname FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'shop' AND p.proname LIKE 'pgv_%'
      AND p.proname NOT IN ('pgv_nav','pgv_money','pgv_badge','pgv_status','pgv_tier','pgv_graph')
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    ORDER BY p.proname
  LOOP
    v_mermaid := v_mermaid || '    fn_' || r.proname || '["' || r.proname || '"]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Business
  v_mermaid := v_mermaid || '  subgraph s_business["Business"]' || chr(10);
  FOR r IN
    SELECT p.proname FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'shop' AND p.proname NOT LIKE 'pgv_%'
      AND p.proname NOT IN ('page','esc','path_segment')
      AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
    ORDER BY p.proname
  LOOP
    v_mermaid := v_mermaid || '    fn_' || r.proname || '["' || r.proname || '"]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Tables
  v_mermaid := v_mermaid || '  subgraph s_tables["Tables"]' || chr(10);
  FOR r IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'shop' ORDER BY tablename
  LOOP
    v_mermaid := v_mermaid || '    tbl_' || r.tablename || '[("' || r.tablename || '")]' || chr(10);
  END LOOP;
  v_mermaid := v_mermaid || '  end' || chr(10);

  -- Edges
  FOR r IN
    SELECT p.proname AS source, d.type AS dep_type, d.name AS target
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'shop'
    CROSS JOIN LATERAL plpgsql_show_dependency_tb(p.oid) d
    WHERE p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
      AND d.schema = 'shop'
      AND d.name NOT IN ('esc','path_segment','pgv_money','pgv_badge','pgv_status','pgv_tier','pgv_nav','pgv_graph')
      AND p.proname NOT IN ('pgv_graph')
    ORDER BY p.proname, d.type, d.name
  LOOP
    IF r.dep_type = 'FUNCTION' THEN
      v_mermaid := v_mermaid || '  fn_' || r.source || ' --> fn_' || r.target || chr(10);
    ELSIF r.dep_type = 'RELATION' AND r.source NOT LIKE 'pgv_%' THEN
      v_mermaid := v_mermaid || '  fn_' || r.source || ' -.-> tbl_' || r.target || chr(10);
    END IF;
  END LOOP;

  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Dependency Graph</h2><p>Auto-generated from plpgsql_check</p></hgroup>';
  v_html := v_html || '<article style="overflow-x:auto"><pre class="mermaid">' || chr(10) || v_mermaid || '</pre></article>';
  v_html := v_html || '<script>
var s = document.createElement("script");
s.src = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js";
s.onload = function() {
  mermaid.initialize({ startOnLoad: false, theme: "default" });
  mermaid.run({ querySelector: ".mermaid" });
};
document.head.appendChild(s);
</script>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_money(numeric); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_money(p_amount numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT '$' || to_char(COALESCE(p_amount, 0), 'FM999,999,990.00');
$_$;


--
-- Name: pgv_nav(text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_nav(p_path text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN format(
    '<nav class="container-fluid" style="border-bottom:1px solid var(--pico-muted-border-color);margin-bottom:2rem">
      <ul><li><strong>pgView Shop</strong></li></ul>
      <ul>
        <li><a href="/" %s>Dashboard</a></li>
        <li><a href="/products" %s>Products</a></li>
        <li><a href="/customers" %s>Customers</a></li>
        <li><a href="/orders" %s>Orders</a></li>
        <li><a href="/discounts" %s>Discounts</a></li>
        <li><a href="/graph" %s>Graph</a></li>
      </ul>
    </nav>',
    CASE WHEN p_path = '/' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/products%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/customers%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/orders%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/discounts%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path = '/graph' THEN 'aria-current="page"' ELSE '' END
  );
END;
$$;


--
-- Name: pgv_order(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_order(p_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html  text;
  v_md    text;
  v_order shop.orders;
  v_cust  shop.customers;
  r       record;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Order not found.</p><footer><a href="/orders">Back</a></footer></article></main>';
  END IF;

  SELECT * INTO v_cust FROM shop.customers WHERE id = v_order.customer_id;

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>Order #%s</h2><p>%s &mdash; %s</p></hgroup>',
    v_order.id, shop.pgv_status(v_order.status),
    to_char(v_order.created_at, 'YYYY-MM-DD HH24:MI'));

  -- Order info card
  v_html := v_html || '<article><dl>';
  v_html := v_html || format('<dt>Customer</dt><dd><a href="/customers/%s">%s</a></dd>',
    v_cust.id, shop.esc(v_cust.name));
  v_html := v_html || format('<dt>Subtotal</dt><dd>%s</dd>', shop.pgv_money(v_order.subtotal));

  IF v_order.discount_code IS NOT NULL THEN
    v_html := v_html || format('<dt>Discount</dt><dd><code>%s</code> &rarr; -%s</dd>',
      shop.esc(v_order.discount_code), shop.pgv_money(v_order.discount_amount));
  ELSIF v_order.discount_amount > 0 THEN
    v_html := v_html || format('<dt>Tier discount</dt><dd>-%s</dd>', shop.pgv_money(v_order.discount_amount));
  END IF;

  v_html := v_html || format('<dt>Total</dt><dd><strong style="font-size:1.2em">%s</strong></dd>',
    shop.pgv_money(v_order.total));
  v_html := v_html || '</dl>';

  -- Cancel button
  IF v_order.status IN ('pending', 'confirmed') THEN
    v_html := v_html || format(
      '<footer><button onclick="post(''/orders/%s/cancel'',{})" class="outline secondary">Cancel Order</button></footer>',
      v_order.id);
  END IF;
  v_html := v_html || '</article>';

  -- Items table (Markdown)
  v_html := v_html || '<h3>Items</h3>';
  v_md := E'| Product | Qty | Unit Price | Subtotal |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT p.name, oi.quantity, oi.unit_price, oi.subtotal
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    WHERE oi.order_id = p_id ORDER BY oi.id
  LOOP
    v_md := v_md || format(E'| %s | %s | %s | %s |\n',
      shop.esc(r.name), r.quantity, shop.pgv_money(r.unit_price),
      shop.pgv_money(r.subtotal));
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  v_html := v_html || '<a href="/orders" role="button" class="outline">Back to orders</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_order_form(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_order_form() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>New Order</h2><p>Place a new order</p></hgroup>';
  v_html := v_html || '<article><form id="order-form">';

  -- Customer select
  v_html := v_html || '<label>Customer';
  v_html := v_html || '<select name="customer_id" required>';
  v_html := v_html || '<option value="">Select a customer...</option>';
  FOR r IN SELECT id, name FROM shop.customers ORDER BY name
  LOOP
    v_html := v_html || format('<option value="%s">%s</option>', r.id, shop.esc(r.name));
  END LOOP;
  v_html := v_html || '</select></label>';

  -- Dynamic item rows
  v_html := v_html || '<fieldset><legend>Products</legend><div id="items"></div>';
  v_html := v_html || '<button type="button" onclick="addItem()">+ Add product</button>';
  v_html := v_html || '<template id="tpl-item"><div class="grid" style="align-items:end">';
  v_html := v_html || '<label>Product<select data-role="pid" required><option value="">--</option>';
  FOR r IN SELECT * FROM shop.products WHERE stock > 0 ORDER BY name
  LOOP
    v_html := v_html || format('<option value="%s">%s (%s, %s in stock)</option>',
      r.id, shop.esc(r.name), shop.pgv_money(r.price), r.stock);
  END LOOP;
  v_html := v_html || '</select></label>';
  v_html := v_html || '<label>Qty<input type="number" data-role="qty" value="1" min="1" style="width:100px"></label>';
  v_html := v_html || '<button type="button" onclick="this.closest(''div'').remove()" class="outline secondary" style="width:auto">x</button>';
  v_html := v_html || '</div></template></fieldset>';

  -- Discount code
  v_html := v_html || '<label>Discount Code (optional)';
  v_html := v_html || '<input type="text" name="discount_code" placeholder="e.g. WELCOME10">';
  v_html := v_html || '</label>';

  v_html := v_html || '<div class="grid">';
  v_html := v_html || '<a href="/orders" role="button" class="outline secondary">Cancel</a>';
  v_html := v_html || '<button type="submit">Place Order</button>';
  v_html := v_html || '</div>';
  v_html := v_html || '</form></article>';

  -- Inline script for form handling
  v_html := v_html || '<script>
function addItem() {
  var tpl = document.getElementById("tpl-item");
  document.getElementById("items").appendChild(tpl.content.cloneNode(true));
}
addItem();
document.getElementById("order-form").addEventListener("submit", function(e) {
  e.preventDefault();
  var items = [];
  document.querySelectorAll("[data-role=pid]").forEach(function(sel) {
    if (!sel.value) return;
    var qty = sel.closest("div").querySelector("[data-role=qty]").value;
    items.push({ product_id: parseInt(sel.value), quantity: parseInt(qty) });
  });
  if (!items.length) { alert("Select at least one product"); return; }
  var cid = this.customer_id.value;
  if (!cid) { alert("Select a customer"); return; }
  post("/orders/place", {
    customer_id: parseInt(cid),
    items: items,
    discount_code: this.discount_code.value || null
  });
});
</script>';

  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_orders(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_orders() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Orders</h2><p>All orders</p></hgroup>';
  v_html := v_html || '<p><a href="/orders/new" role="button">+ New Order</a></p>';

  v_md := E'| # | Customer | Status | Items | Total | Date |\n| --- | --- | --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt,
           (SELECT count(*) FROM shop.order_items WHERE order_id = o.id) AS items
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s | %s | %s |\n',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      r.items, shop.pgv_money(r.total), r.dt);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_place_order(jsonb); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_place_order(p_body jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_order_id integer;
BEGIN
  v_order_id := shop.place_order(
    (p_body->>'customer_id')::integer,
    p_body->'items',
    p_body->>'discount_code'
  );
  RETURN '<!-- redirect:/orders/' || v_order_id || ' -->';
EXCEPTION WHEN OTHERS THEN
  RETURN '<main class="container"><article>'
    || '<header>Error</header>'
    || '<p>' || shop.esc(SQLERRM) || '</p>'
    || '<footer><a href="/orders/new" role="button" class="outline">Try again</a></footer>'
    || '</article></main>';
END;
$$;


--
-- Name: pgv_product(integer); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_product(p_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  r shop.products;
BEGIN
  SELECT * INTO r FROM shop.products WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Product not found.</p><footer><a href="/products">Back</a></footer></article></main>';
  END IF;

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>%s</h2><p>Product #%s</p></hgroup>', shop.esc(r.name), r.id);
  v_html := v_html || '<article><dl>';
  v_html := v_html || format('<dt>Price</dt><dd><strong>%s</strong></dd>', shop.pgv_money(r.price));
  v_html := v_html || format('<dt>Stock</dt><dd>%s units</dd>', r.stock);
  v_html := v_html || format('<dt>Status</dt><dd>%s</dd>',
    CASE WHEN r.stock > 0 THEN shop.pgv_badge('In Stock', 'success')
         ELSE shop.pgv_badge('Out of Stock', 'danger') END);
  v_html := v_html || '</dl>';
  v_html := v_html || '<footer><a href="/products" role="button" class="outline">Back to catalog</a></footer>';
  v_html := v_html || '</article></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_products(); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_products() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Products</h2><p>Catalog</p></hgroup>';

  v_md := E'| Name | Price | Stock |\n| --- | --- | --- |\n';
  FOR r IN SELECT * FROM shop.products ORDER BY name
  LOOP
    v_md := v_md || format(E'| <a href="/products/%s">%s</a> | %s | %s |\n',
      r.id, shop.esc(r.name), shop.pgv_money(r.price),
      CASE WHEN r.stock > 10 THEN shop.pgv_badge(r.stock || '', 'success')
           WHEN r.stock > 0  THEN shop.pgv_badge(r.stock || '', 'warning')
           ELSE shop.pgv_badge('Out of stock', 'danger') END);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$$;


--
-- Name: pgv_status(text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_status(p_status text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT shop.pgv_badge(p_status,
    CASE p_status
      WHEN 'confirmed' THEN 'success'
      WHEN 'shipped'   THEN 'info'
      WHEN 'pending'   THEN 'warning'
      WHEN 'cancelled' THEN 'danger'
      ELSE 'default'
    END);
$$;


--
-- Name: pgv_tier(text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.pgv_tier(p_tier text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT shop.pgv_badge(p_tier, p_tier);
$$;


--
-- Name: place_order(integer, jsonb, text); Type: FUNCTION; Schema: shop; Owner: -
--

CREATE FUNCTION shop.place_order(p_customer_id integer, p_items jsonb, p_discount_code text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_order_id integer;
  v_item jsonb;
  v_product shop.products;
  v_qty integer;
  v_subtotal numeric := 0;
  v_item_count integer := 0;
  v_discount numeric := 0;
  v_tier_pct numeric;
BEGIN
  -- Validate customer
  PERFORM 1 FROM shop.customers WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'customer % not found', p_customer_id;
  END IF;

  -- Create order
  INSERT INTO shop.orders (customer_id) VALUES (p_customer_id) RETURNING id INTO v_order_id;

  -- Process items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_product
    FROM shop.products
    WHERE id = (v_item->>'product_id')::integer
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'product % not found', v_item->>'product_id';
    END IF;

    v_qty := (v_item->>'quantity')::integer;

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'quantity must be positive for product %', v_product.name;
    END IF;

    IF v_product.stock < v_qty THEN
      RAISE EXCEPTION 'insufficient stock for "%": have %, need %',
        v_product.name, v_product.stock, v_qty;
    END IF;

    -- Reserve stock
    UPDATE shop.products SET stock = stock - v_qty WHERE id = v_product.id;

    -- Add line item
    INSERT INTO shop.order_items (order_id, product_id, quantity, unit_price, subtotal)
    VALUES (v_order_id, v_product.id, v_qty, v_product.price, v_product.price * v_qty);

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_item_count := v_item_count + v_qty;
  END LOOP;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'order must contain at least one item';
  END IF;

  -- Apply discount code
  IF p_discount_code IS NOT NULL THEN
    v_discount := shop.apply_discount(p_discount_code, v_subtotal, v_item_count);
  END IF;

  -- Apply tier discount (stacks with code discount)
  v_tier_pct := CASE shop.customer_tier(p_customer_id)
    WHEN 'platinum' THEN 10
    WHEN 'gold' THEN 5
    WHEN 'silver' THEN 2
    ELSE 0
  END;

  IF v_tier_pct > 0 THEN
    v_discount := v_discount + ROUND((v_subtotal - v_discount) * v_tier_pct / 100, 2);
  END IF;

  -- Finalize
  UPDATE shop.orders
  SET subtotal = v_subtotal,
      discount_amount = v_discount,
      total = v_subtotal - v_discount,
      discount_code = p_discount_code,
      status = 'confirmed'
  WHERE id = v_order_id;

  RETURN v_order_id;
END;
$$;


--
-- Name: test_apply_discount(); Type: FUNCTION; Schema: shop_ut; Owner: -
--

CREATE FUNCTION shop_ut.test_apply_discount() RETURNS SETOF text
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_amount numeric;
BEGIN
  -- Percentage discount: WELCOME10 = 10%
  v_amount := shop.apply_discount('WELCOME10', 100.00, 1);
  RETURN NEXT is(v_amount, 10.00, 'WELCOME10 gives 10% off');

  -- Fixed discount: FLAT25 = $25 off
  v_amount := shop.apply_discount('FLAT25', 100.00, 1);
  RETURN NEXT is(v_amount, 25.00, 'FLAT25 gives $25 off');

  -- Fixed discount capped at subtotal
  v_amount := shop.apply_discount('FLAT25', 10.00, 1);
  RETURN NEXT is(v_amount, 10.00, 'FLAT25 capped at subtotal when subtotal < 25');

  -- Buy X Get Y: BUY2GET1 = buy 2 get 1 free
  v_amount := shop.apply_discount('BUY2GET1', 90.00, 3);
  RETURN NEXT ok(v_amount > 0, 'BUY2GET1 gives a discount for 3 items');

  -- Unknown code
  RETURN NEXT throws_ok(
    'SELECT shop.apply_discount(''NOPE'', 100.00, 1)',
    'discount code "NOPE" not found');

  -- Inactive code
  RETURN NEXT throws_ok(
    'SELECT shop.apply_discount(''EXPIRED50'', 100.00, 1)',
    'discount code "EXPIRED50" is inactive');
END;
$_$;


--
-- Name: test_cancel_order(); Type: FUNCTION; Schema: shop_ut; Owner: -
--

CREATE FUNCTION shop_ut.test_cancel_order() RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_order_id integer;
  v_result boolean;
  v_stock_before integer;
  v_stock_after integer;
BEGIN
  -- Setup: place an order
  SELECT stock INTO v_stock_before FROM shop.products WHERE id = 1;
  v_order_id := shop.place_order(1, '[{"product_id":1,"quantity":1}]'::jsonb);

  -- Cancel it
  v_result := shop.cancel_order(v_order_id);
  RETURN NEXT ok(v_result, 'cancel_order returns true');

  RETURN NEXT is(
    (SELECT status FROM shop.orders WHERE id = v_order_id),
    'cancelled', 'order status is cancelled');

  -- Stock restored
  SELECT stock INTO v_stock_after FROM shop.products WHERE id = 1;
  RETURN NEXT is(v_stock_after, v_stock_before, 'stock restored after cancel');

  -- Idempotent: cancel again returns false
  v_result := shop.cancel_order(v_order_id);
  RETURN NEXT ok(NOT v_result, 'cancel_order is idempotent (returns false)');

  -- Non-existent order
  RETURN NEXT throws_ok(
    format('SELECT shop.cancel_order(%s)', 99999),
    'order 99999 not found');
END;
$$;


--
-- Name: test_customer_tier(); Type: FUNCTION; Schema: shop_ut; Owner: -
--

CREATE FUNCTION shop_ut.test_customer_tier() RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_tier text;
BEGIN
  -- Customer 1 has orders, should have a tier
  v_tier := shop.customer_tier(1);
  RETURN NEXT ok(v_tier IN ('bronze', 'silver', 'gold', 'platinum'),
    'customer_tier returns a valid tier: ' || v_tier);

  -- Non-existent customer → bronze (0 spent)
  v_tier := shop.customer_tier(99999);
  RETURN NEXT is(v_tier, 'bronze', 'non-existent customer gets bronze');
END;
$$;


--
-- Name: test_place_order(); Type: FUNCTION; Schema: shop_ut; Owner: -
--

CREATE FUNCTION shop_ut.test_place_order() RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_order_id integer;
  v_order shop.orders;
  v_stock_before integer;
  v_stock_after integer;
BEGIN
  -- Get initial stock
  SELECT stock INTO v_stock_before FROM shop.products WHERE id = 1;

  -- Place a simple order
  v_order_id := shop.place_order(
    1,
    '[{"product_id":1,"quantity":2}]'::jsonb
  );
  RETURN NEXT ok(v_order_id IS NOT NULL, 'place_order returns an order id');

  SELECT * INTO v_order FROM shop.orders WHERE id = v_order_id;
  RETURN NEXT is(v_order.status, 'confirmed', 'order status is confirmed');
  RETURN NEXT ok(v_order.total > 0, 'order total is positive');
  RETURN NEXT ok(v_order.subtotal >= v_order.total, 'total <= subtotal (tier discount may apply)');

  -- Stock decreased
  SELECT stock INTO v_stock_after FROM shop.products WHERE id = 1;
  RETURN NEXT is(v_stock_after, v_stock_before - 2, 'stock decreased by quantity');

  -- Items created
  RETURN NEXT is(
    (SELECT count(*)::integer FROM shop.order_items WHERE order_id = v_order_id),
    1, 'one line item created');

  -- Invalid customer
  RETURN NEXT throws_ok(
    'SELECT shop.place_order(9999, ''[{"product_id":1,"quantity":1}]''::jsonb)',
    'customer 9999 not found');

  -- Empty items
  RETURN NEXT throws_ok(
    'SELECT shop.place_order(1, ''[]''::jsonb)',
    'order must contain at least one item');
END;
$$;


--
-- Name: agent; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.agent (
    id text NOT NULL,
    role organic.agent_role NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.entity (
    id text NOT NULL,
    kind organic.entity_kind NOT NULL,
    name text,
    description text,
    content text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity_rel; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.entity_rel (
    from_kind organic.entity_kind NOT NULL,
    from_id text NOT NULL,
    rel_type text NOT NULL,
    to_kind organic.entity_kind NOT NULL,
    to_id text NOT NULL
);


--
-- Name: event; Type: TABLE; Schema: organic; Owner: -
--

CREATE TABLE organic.event (
    id bigint NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    action text NOT NULL,
    payload jsonb,
    actor text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: event_id_seq; Type: SEQUENCE; Schema: organic; Owner: -
--

ALTER TABLE organic.event ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME organic.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: customers; Type: TABLE; Schema: shop; Owner: -
--

CREATE TABLE shop.customers (
    id integer NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: shop; Owner: -
--

CREATE SEQUENCE shop.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: shop; Owner: -
--

ALTER SEQUENCE shop.customers_id_seq OWNED BY shop.customers.id;


--
-- Name: discounts; Type: TABLE; Schema: shop; Owner: -
--

CREATE TABLE shop.discounts (
    code text NOT NULL,
    kind text NOT NULL,
    value numeric(10,2) NOT NULL,
    min_order numeric(10,2) DEFAULT 0,
    buy_x integer,
    get_y_free integer,
    active boolean DEFAULT true,
    expires_at timestamp with time zone,
    CONSTRAINT discounts_kind_check CHECK ((kind = ANY (ARRAY['percentage'::text, 'fixed'::text, 'buy_x_get_y'::text])))
);


--
-- Name: order_items; Type: TABLE; Schema: shop; Owner: -
--

CREATE TABLE shop.order_items (
    id integer NOT NULL,
    order_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: shop; Owner: -
--

CREATE SEQUENCE shop.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: shop; Owner: -
--

ALTER SEQUENCE shop.order_items_id_seq OWNED BY shop.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: shop; Owner: -
--

CREATE TABLE shop.orders (
    id integer NOT NULL,
    customer_id integer NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    subtotal numeric(10,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    total numeric(10,2) DEFAULT 0 NOT NULL,
    discount_code text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'shipped'::text, 'cancelled'::text])))
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: shop; Owner: -
--

CREATE SEQUENCE shop.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: shop; Owner: -
--

ALTER SEQUENCE shop.orders_id_seq OWNED BY shop.orders.id;


--
-- Name: products; Type: TABLE; Schema: shop; Owner: -
--

CREATE TABLE shop.products (
    id integer NOT NULL,
    name text NOT NULL,
    price numeric(10,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    CONSTRAINT products_price_check CHECK ((price > (0)::numeric)),
    CONSTRAINT products_stock_check CHECK ((stock >= 0))
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: shop; Owner: -
--

CREATE SEQUENCE shop.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: shop; Owner: -
--

ALTER SEQUENCE shop.products_id_seq OWNED BY shop.products.id;


--
-- Name: customers id; Type: DEFAULT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.customers ALTER COLUMN id SET DEFAULT nextval('shop.customers_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.order_items ALTER COLUMN id SET DEFAULT nextval('shop.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.orders ALTER COLUMN id SET DEFAULT nextval('shop.orders_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.products ALTER COLUMN id SET DEFAULT nextval('shop.products_id_seq'::regclass);


--
-- Data for Name: agent; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.agent (id, role, active, created_at) FROM stdin;
owner-1	owner	t	2026-03-08 11:32:12.671085+00
lead-1	lead	t	2026-03-08 11:32:12.671085+00
craftsman-1	craftsman	t	2026-03-08 11:32:12.671085+00
\.


--
-- Data for Name: entity; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.entity (id, kind, name, description, content, metadata, created_at) FROM stdin;
self-description	capability	Self-Description	\N	Le système sait exprimer sa propre structure — le schéma YAML est la source de vérité unique, les CRDs décrivent les kinds, et la génération Cypher est déterministe.	{}	2026-03-08 11:37:37.916531+00
self-diagnosis	capability	Self-Diagnosis	\N	Le système sait se diagnostiquer — il calcule la maturity de chaque entité, observe sa constellation de facets, et vérifie la couverture code→graph.	{}	2026-03-08 11:37:37.916531+00
external-absorption	capability	External Absorption	\N	Le système sait communiquer avec le monde extérieur — absorber des données depuis des sources variées via des Drivers déclaratifs et des adapters typés.	{}	2026-03-08 11:37:37.916531+00
deployment	capability	Deployment	\N	Le système sait se déployer — prendre vie comme service MCP, valider son schéma, et s'exécuter dans un environnement Docker reproductible.	{}	2026-03-08 11:37:37.916531+00
exposure	capability	Exposure	\N	Le système sait s'exposer — rendre visible son état interne via une UI React, le Graph View Protocol (GVP), et les outils MCP.	{}	2026-03-08 11:37:37.916531+00
delegation	capability	Delegation	\N	Le système peut déléguer à des agents — les roles, les tasks, le permission bridge, le contrôle humain.	{}	2026-03-08 11:37:37.916531+00
self-archival	capability	Self-Archival	\N	Le système sait s'archiver — consolider son graph périodiquement, séparer le chaud du froid, et produire des snapshots.	{}	2026-03-08 11:37:37.916531+00
reactivity	capability	Reactivity	\N	Le système réagit aux événements du graph — mutations internes et événements externes (commits, webhooks).	{}	2026-03-08 11:37:37.916531+00
agent-model	pattern	Agent Model	\N	Modèle de délégation d'un domaine Organic à des agents LLM. Domain-agnostic — chaque domaine instancie ses propres rôles et primitives.	{}	2026-03-08 11:38:13.347153+00
analysis-as-proof	pattern	Analysis as Proof	\N	Le commit est la preuve — l'analyse le confirme. Le plugin commit-analysis analyse les fichiers changés et résout chaque fichier vers un Module du graph.	{}	2026-03-08 11:38:13.347153+00
client-layout	pattern	Client Layout	\N	Layout spec du client Organic. Shell = App, zones Header + Canvas.	{}	2026-03-08 11:38:13.347153+00
constellation	pattern	Constellation	\N	Une entité est une constellation de facets. La Capability est l'entité principale — les adjacentes (Pattern, Module, Domain) jouent le rôle de facets.	{}	2026-03-08 11:38:13.347153+00
contextual-memory	pattern	Contextual Memory	\N	Les reminders sont des relations (pas des noeuds) entre un rôle et une cible. Mémoire contextuelle pour les agents.	{}	2026-03-08 11:38:13.347153+00
crd-model	pattern	CRD Model	\N	Domaine Organic — modéliser le développement dans un graphe. Un organisme qui se reproduit à travers ses domaines.	{}	2026-03-08 11:38:13.347153+00
declarative-injection	pattern	Declarative Injection	\N	Le code généré ne hardcode jamais de valeur spécifique au domaine. Tout est lu depuis le CRD YAML et injecté via des variables.	{}	2026-03-08 11:38:13.347153+00
dependency-guards	pattern	Dependency Guards	\N	Contraintes inter-ressources. Une action ne s'exerce jamais sur une entité isolée — elle met en jeu un réseau de ressources dont l'état conditionne ce qui est possible.	{}	2026-03-08 11:38:13.347153+00
domain-yaml-authoring	pattern	Domain YAML Authoring	\N	Guide pour écrire un domain.yaml qui fonctionne du premier coup. Leçons tirées du bootstrap du domaine council.	{}	2026-03-08 11:38:13.347153+00
driver-crd	pattern	Driver CRD	\N	Connexion déclarative aux sources de données. Un kind: Driver dans le domain.yaml déclare une source (neo4j, git, rpc, webhook).	{}	2026-03-08 11:38:13.347153+00
entity-adapter	pattern	Entity Adapter	\N	Une Entity déclare comment elle se projette depuis une source externe. L'Entity est autonome : elle sait ce qu'elle est ET comment se lire/écrire.	{}	2026-03-08 11:38:13.347153+00
event-driven-triggers	pattern	Event-Driven Triggers	\N	Réactivité déclarative sur le graph. Un Trigger CRD déclare : quand un événement survient, exécuter une action via un Driver.	{}	2026-03-08 11:38:13.347153+00
generated-runtime	pattern	Generated Runtime	\N	L'organisme distribué. Trois couches dans des process séparés, coordonnées par le Makefile.	{}	2026-03-08 11:38:13.347153+00
gvp	pattern	Graph View Protocol	\N	Format textuel optimisé pour l'attention LLM. Les outils MCP retournent du GVP, pas du JSON. Sections @entity, @spec, @relations, @maturity, @links.	{}	2026-03-08 11:38:13.347153+00
hot-cold-consolidation	pattern	Hot-Cold Consolidation	\N	Deux couches de stockage. Hot = données vivantes 90 jours. Cold = archive 3 ans partitionnée.	{}	2026-03-08 11:38:13.347153+00
intent-execution	pattern	Intent Execution	\N	Governed lifecycle. Primitives read/find/create/refine/wire avec attestation par token.	{}	2026-03-08 11:38:13.347153+00
intent-task-dispatch	pattern	Intent Task Dispatch	\N	Intent → Task → ASSIGNS → Dispatch → Agent → Completion → Rescan. Workflow de délégation gouverné.	{}	2026-03-08 11:38:13.347153+00
json-rpc-protocol	pattern	JSON-RPC Protocol	\N	Protocole unique JSON-RPC 2.0 pour toutes les communications : hook→serveur, client→serveur, serveur→client.	{}	2026-03-08 11:38:13.347153+00
maturity-model	pattern	Maturity Model	\N	La maturity d'une Capability est émergente : calculée depuis la présence de facets, pas déclarée manuellement.	{}	2026-03-08 11:38:13.347153+00
read-attestation	pattern	Read Attestation	\N	La mutation est une conséquence de la lecture, pas un droit. Un agent ne peut modifier que ce qu'il a lu. Tokens opaques.	{}	2026-03-08 11:38:13.347153+00
rpc-plugin	pattern	RPC Plugin	\N	Extension du serveur JSON-RPC 2.0 avec des plugins TypeScript hot-reloadable. Chaque plugin default-exporte un RpcPlugin.	{}	2026-03-08 11:38:13.347153+00
schedule-triggers	pattern	Schedule Triggers	\N	Exécution périodique de requêtes Cypher côté serveur. setInterval Node.js, pas APOC.	{}	2026-03-08 11:38:13.347153+00
structured-commits	pattern	Structured Commits	\N	Convention de commit avec YAML front matter, appliquée par des hooks git et tracée dans le graphe.	{}	2026-03-08 11:38:13.347153+00
trigger-sandbox	pattern	Trigger Sandbox	\N	Valider la chaîne de triggers d'un domaine en simulation e2e, sans agents.	{}	2026-03-08 11:38:13.347153+00
ui-model	pattern	UI Model	\N	Interface active pour naviguer le graph et piloter l'agent. React 19 + Vite 6 + Zustand 5 + D3 7.	{}	2026-03-08 11:38:13.347153+00
uri-navigation	pattern	URI Navigation	\N	Un agent qui a une URI et des links navigue. 5 primitives au lieu de 19 outils. HATEOAS pour LLM.	{}	2026-03-08 11:38:13.347153+00
agent-panel	module	Agent Panel	\N	UI de communication avec l'agent. Panel latéral gauche, dashboard vivant.	{}	2026-03-08 11:38:40.743752+00
agent-runtime	module	Agent Runtime	\N	\N	{}	2026-03-08 11:38:40.743752+00
claude-agent	module	Claude Agent	\N	Adaptateur côté serveur entre Claude Code et l'orchestrator. Traduit les hook events en payloads canoniques.	{}	2026-03-08 11:38:40.743752+00
client-ui	module	Client UI	\N	Client UI React + Zustand. Store 5 slices, data-driven via domain-config poussé par WebSocket. D3 pour le rendu graph SVG.	{}	2026-03-08 11:38:40.743752+00
container	module	DI Container	\N	Container Awilix qui résout le graphe de dépendances du serveur : drivers, bridge orchestrateur, configs YAML, tool runtime, tool registry.	{}	2026-03-08 11:38:40.743752+00
docker-compose	module	Docker Compose	\N	Container Neo4j Community par domaine. docker-compose.yaml avec healthcheck Bolt, volumes persistants.	{}	2026-03-08 11:38:40.743752+00
doctor	module	Doctor	\N	Agent builtin de type doctor. Médecin du village — tourne en permanence, dépile les événements, diagnostique.	{}	2026-03-08 11:38:40.743752+00
domain-loader	module	Domain Loader	\N	YAML parser (Self, Entity, Intent, Driver, Consolidation, Trigger) + build configs runtime.	{}	2026-03-08 11:38:40.743752+00
driver-adapters	module	Driver Adapters	\N	\N	{}	2026-03-08 11:38:40.743752+00
driver-google	module	Google Driver	\N	Adapter OAuth2 pour les APIs Google (Gmail, Drive). Plugin dans server/drivers/google.ts.	{}	2026-03-08 11:38:40.743752+00
graph-api	module	Graph API	\N	Serveur de domaine exposant le graph Neo4j via les primitives MCP. read, find, create, refine, wire.	{}	2026-03-08 11:38:40.743752+00
graph-explorer	module	Graph Explorer	\N	Composant React GraphExplorer.tsx. D3 force-directed graph. Config dynamique depuis le schema.	{}	2026-03-08 11:38:40.743752+00
json-schema	module	JSON Schema Validator	\N	schemas/domain.schema.json — JSON Schema + scripts/validate-domain.mjs — CLI validator.	{}	2026-03-08 11:38:40.743752+00
makefile	module	Makefile	\N	Build pipeline orchestrator: make generate, make schema, make dev. Governed by build-via-makefile norm.	{}	2026-03-08 11:38:40.743752+00
mcp-server	module	MCP Server	\N	Montage des outils MCP, token registry, request context, role filtering.	{}	2026-03-08 11:38:40.743752+00
orchestrator	module	Orchestrator	\N	Package standalone @organic/orchestrator — gère le pool d'agents, le dispatch de tasks, et les sessions terminal.	{}	2026-03-08 11:38:40.743752+00
permission-bridge	module	Permission Bridge	\N	Permission bridge — long-poll /api/perm/wait. Bloque l'agent jusqu'à réponse humaine dans l'UI.	{}	2026-03-08 11:38:40.743752+00
post-commit-hook	module	Post-Commit Hook	\N	Hooks Git — scripts/hooks/. commit-msg valide le front matter YAML, post-commit crée la relation COMMITTED.	{}	2026-03-08 11:38:40.743752+00
rpc-handler	module	RPC Handler	\N	\N	{}	2026-03-08 11:38:40.743752+00
rpc-plugins	module	RPC Plugins	\N	Loader, hot-reload watcher, PluginContext builder. Individual plugin files dans server/plugins/.	{}	2026-03-08 11:38:40.743752+00
scheduler	module	Scheduler	\N	Module serveur qui lit les triggers event: schedule du domain.yaml et les exécute périodiquement via setInterval.	{}	2026-03-08 11:38:40.743752+00
shared-types	module	Shared Types	\N	Package shared/types.ts. Source unique pour les types partagés server↔client.	{}	2026-03-08 11:38:40.743752+00
state-orchestrator	module	State Orchestrator	\N	\N	{}	2026-03-08 11:38:40.743752+00
telegram-bot	module	Telegram Bot	\N	Dialogue avec l'agent Organic directement depuis Telegram. Boutons interactifs, texte libre.	{}	2026-03-08 11:38:40.743752+00
terminal-view	module	Terminal View	\N	\N	{}	2026-03-08 11:38:40.743752+00
ws-relay	module	WS Relay	\N	WebSocket relay — pousse les événements du bus serveur vers le client.	{}	2026-03-08 11:38:40.743752+00
agora	domain	Agora	\N	Réseau social d'agents. 6 rôles (moderator, sceptique, poète, pragmatique, connecteur, novice). Entities: Agent, Post, Skill. Intent permanent social-life.	{}	2026-03-08 11:41:23.836724+00
council	domain	Council	\N	Délibération produit. 3 rôles (structure, risque, effort) convergent par proposals successives vers un consensus. Entities: Discussion, Proposal.	{}	2026-03-08 11:41:23.836724+00
crm-b2b	domain	CRM B2B	\N	CRM B2B générique. Pipeline commercial : lead brut → opportunité engagée. 3 rôles (sdr, assistant, manager). Entity: Lead.	{}	2026-03-08 11:41:23.836724+00
orchestration-lab	domain	Orchestration Lab	\N	Domaine de test isolé pour valider l'orchestration : behaviors, doctor, voice enforcement, dispatch, intent lifecycle.	{}	2026-03-08 11:41:23.836724+00
organic-dev	domain	Organic Dev	\N	Organic modélise son propre développement. Le domaine organic est à la fois le produit et son propre terrain de validation.	{}	2026-03-08 11:41:23.836724+00
personal	domain	Personal	\N	Indexation documentaire. Organic indexe les documents personnels sans jamais les déplacer. Les catégories émergent du contenu via résumé LLM.	{}	2026-03-08 11:41:23.836724+00
tourisme	domain	Tourisme	\N	Gestion de prospects et groupes touristiques. Premier domaine enfant, valide le moteur en conditions réelles.	{}	2026-03-08 11:41:23.836724+00
\.


--
-- Data for Name: entity_rel; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.entity_rel (from_kind, from_id, rel_type, to_kind, to_id) FROM stdin;
capability	delegation	DEFINES	pattern	agent-model
capability	delegation	DEFINES	pattern	contextual-memory
capability	delegation	DEFINES	pattern	dependency-guards
capability	delegation	DEFINES	pattern	intent-execution
capability	delegation	DEFINES	pattern	intent-task-dispatch
capability	delegation	DEFINES	pattern	read-attestation
capability	delegation	DEFINES	pattern	rpc-plugin
capability	deployment	DEFINES	pattern	generated-runtime
capability	exposure	DEFINES	pattern	client-layout
capability	exposure	DEFINES	pattern	gvp
capability	exposure	DEFINES	pattern	ui-model
capability	external-absorption	DEFINES	pattern	driver-crd
capability	external-absorption	DEFINES	pattern	entity-adapter
capability	external-absorption	DEFINES	pattern	json-rpc-protocol
capability	reactivity	DEFINES	pattern	event-driven-triggers
capability	reactivity	DEFINES	pattern	schedule-triggers
capability	self-archival	DEFINES	pattern	hot-cold-consolidation
capability	self-description	DEFINES	pattern	crd-model
capability	self-description	DEFINES	pattern	declarative-injection
capability	self-description	DEFINES	pattern	domain-yaml-authoring
capability	self-description	DEFINES	pattern	structured-commits
capability	self-description	DEFINES	pattern	uri-navigation
capability	self-diagnosis	DEFINES	pattern	analysis-as-proof
capability	self-diagnosis	DEFINES	pattern	constellation
capability	self-diagnosis	DEFINES	pattern	maturity-model
capability	self-diagnosis	DEFINES	pattern	trigger-sandbox
capability	delegation	SUSTAINS	module	claude-agent
capability	delegation	SUSTAINS	module	container
capability	delegation	SUSTAINS	module	doctor
capability	delegation	SUSTAINS	module	orchestrator
capability	delegation	SUSTAINS	module	rpc-handler
capability	delegation	SUSTAINS	module	rpc-plugins
capability	delegation	SUSTAINS	module	terminal-view
capability	deployment	SUSTAINS	module	docker-compose
capability	deployment	SUSTAINS	module	json-schema
capability	deployment	SUSTAINS	module	makefile
capability	exposure	SUSTAINS	module	agent-panel
capability	exposure	SUSTAINS	module	client-ui
capability	exposure	SUSTAINS	module	graph-api
capability	exposure	SUSTAINS	module	graph-explorer
capability	exposure	SUSTAINS	module	permission-bridge
capability	exposure	SUSTAINS	module	shared-types
capability	exposure	SUSTAINS	module	state-orchestrator
capability	exposure	SUSTAINS	module	ws-relay
capability	external-absorption	SUSTAINS	module	driver-adapters
capability	external-absorption	SUSTAINS	module	driver-google
capability	reactivity	SUSTAINS	module	rpc-plugins
capability	reactivity	SUSTAINS	module	scheduler
capability	self-description	SUSTAINS	module	domain-loader
capability	self-description	SUSTAINS	module	graph-api
capability	self-description	SUSTAINS	module	post-commit-hook
capability	self-diagnosis	SUSTAINS	module	graph-api
module	agent-panel	IMPLEMENTS	pattern	ui-model
module	agent-runtime	IMPLEMENTS	pattern	agent-model
module	claude-agent	IMPLEMENTS	pattern	agent-model
module	client-ui	IMPLEMENTS	pattern	ui-model
module	docker-compose	IMPLEMENTS	pattern	generated-runtime
module	doctor	IMPLEMENTS	pattern	agent-model
module	domain-loader	IMPLEMENTS	pattern	crd-model
module	driver-adapters	IMPLEMENTS	pattern	driver-crd
module	driver-adapters	IMPLEMENTS	pattern	entity-adapter
module	driver-google	IMPLEMENTS	pattern	driver-crd
module	graph-api	IMPLEMENTS	pattern	constellation
module	graph-api	IMPLEMENTS	pattern	gvp
module	graph-explorer	IMPLEMENTS	pattern	ui-model
module	graph-explorer	IMPLEMENTS	pattern	uri-navigation
module	json-schema	IMPLEMENTS	pattern	crd-model
module	makefile	IMPLEMENTS	pattern	generated-runtime
module	mcp-server	IMPLEMENTS	pattern	json-rpc-protocol
module	orchestrator	IMPLEMENTS	pattern	agent-model
module	permission-bridge	IMPLEMENTS	pattern	agent-model
module	permission-bridge	IMPLEMENTS	pattern	ui-model
module	post-commit-hook	IMPLEMENTS	pattern	uri-navigation
module	rpc-handler	IMPLEMENTS	pattern	json-rpc-protocol
module	rpc-plugins	IMPLEMENTS	pattern	rpc-plugin
module	scheduler	IMPLEMENTS	pattern	schedule-triggers
module	shared-types	IMPLEMENTS	pattern	ui-model
module	state-orchestrator	IMPLEMENTS	pattern	ui-model
module	telegram-bot	IMPLEMENTS	pattern	rpc-plugin
module	terminal-view	IMPLEMENTS	pattern	agent-model
module	ws-relay	IMPLEMENTS	pattern	generated-runtime
module	ws-relay	IMPLEMENTS	pattern	ui-model
capability	deployment	VERIFIES	domain	tourisme
capability	exposure	VERIFIES	domain	tourisme
capability	external-absorption	VERIFIES	domain	organic-dev
capability	external-absorption	VERIFIES	domain	tourisme
capability	self-description	VERIFIES	domain	organic-dev
capability	self-description	VERIFIES	domain	tourisme
capability	self-diagnosis	VERIFIES	domain	tourisme
module	agent-panel	DEPENDS_ON	module	client-ui
module	agent-panel	DEPENDS_ON	module	shared-types
module	agent-panel	DEPENDS_ON	module	ws-relay
module	agent-runtime	DEPENDS_ON	module	orchestrator
module	claude-agent	DEPENDS_ON	module	orchestrator
module	claude-agent	DEPENDS_ON	module	shared-types
module	client-ui	DEPENDS_ON	module	shared-types
module	client-ui	DEPENDS_ON	module	ws-relay
module	container	DEPENDS_ON	module	domain-loader
module	container	DEPENDS_ON	module	mcp-server
module	container	DEPENDS_ON	module	state-orchestrator
module	doctor	DEPENDS_ON	module	orchestrator
module	driver-adapters	DEPENDS_ON	module	graph-api
module	driver-google	DEPENDS_ON	module	driver-adapters
module	graph-explorer	DEPENDS_ON	module	client-ui
module	graph-explorer	DEPENDS_ON	module	shared-types
module	permission-bridge	DEPENDS_ON	module	shared-types
module	post-commit-hook	DEPENDS_ON	module	graph-api
module	post-commit-hook	DEPENDS_ON	module	ws-relay
module	rpc-handler	DEPENDS_ON	module	ws-relay
module	rpc-plugins	DEPENDS_ON	module	graph-api
module	state-orchestrator	DEPENDS_ON	module	ws-relay
module	telegram-bot	DEPENDS_ON	module	rpc-plugins
module	terminal-view	DEPENDS_ON	module	orchestrator
module	terminal-view	DEPENDS_ON	module	ws-relay
module	ws-relay	DEPENDS_ON	module	shared-types
\.


--
-- Data for Name: event; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.event (id, entity_type, entity_id, action, payload, actor, created_at) FROM stdin;
\.


--
-- Data for Name: intent; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.intent (id, name, description, state, created_by, created_at, updated_at) FROM stdin;
check-write-tool-properties	Check write tool properties	Les outils d'écriture (create, refine) ne valorisent pas toujours toutes les properties attendues.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
client-nav-stack	Client navigation stack	Navigation stack côté client — back/forward, breadcrumbs, conscience spatiale dans le graph.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
fix-token-scope	Fix token scope	Corriger les problèmes de token scope dans le token-registry.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
http-hooks-migration	HTTP hooks migration	Migrer les hooks Claude Code de command (bash + curl JSON-RPC) vers HTTP (POST direct).	declared	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
inline-edit	Inline edit	Édition inline du contenu markdown des entités.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
patch-tool	Patch tool	Outil MCP patch pour proposer des modifications partielles sur les propriétés texte des entities.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
trigger-control	Trigger control	Exposer les schedule triggers via RPC et permettre au front de les piloter.	engaged	owner-1	2026-03-08 11:35:48.446927+00	2026-03-08 11:35:48.446927+00
json-rpc-protocol	JSON-RPC protocol	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
gvp-ergonomics	GVP ergonomics	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
driver-entity-adapter	Driver + Entity Adapter	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
centralize-constants	Centralize constants	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
read-attestation-primitives	Read attestation primitives	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
domain-model-v5	Domain model v5	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
domain-model-v6	Domain model v6	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
schema-generator-ts	Schema generator TS	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
trigger-kind	Trigger kind	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
orchestrator-decomposition	Orchestrator decomposition	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
awilix-di-container	Awilix DI container	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
pluggable-architecture	Pluggable architecture	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
task-delegation	Task delegation	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
structured-graph-view	Structured graph view	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
schema-driven-ui	Schema driven UI	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
emit-view-models	Emit view models	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
unified-view-model	Unified view model	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
graph-search	Graph search	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
search-tool	Search tool	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
intent-runtime-extraction	Intent runtime extraction	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
analysis-as-proof	Analysis as proof	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
allowed-tools-enforcement	Allowed tools enforcement	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
context-monitoring	Context monitoring	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
council-domain	Council domain	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
reliable-prompt-delivery	Reliable prompt delivery	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
voice-hardening	Voice hardening	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
markdown-features	Markdown features	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
gvp-hardening	GVP hardening	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
server-boundaries	Server boundaries	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
review-orchestrator	Review orchestrator	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
telegram-bot	Telegram bot	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
gmail-agent-pipeline	Gmail agent pipeline	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
driver-collection	Driver collection	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
driver-auth-lifecycle	Driver auth lifecycle	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
console-redesign	Console redesign	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
structured-view-layout	Structured view layout	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
client-review-fixes	Client review fixes	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
decouple-agent-runtime	Decouple agent runtime	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
dispatch-completion-rpc	Dispatch completion RPC	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
document-intent-task-dispatch	Document intent/task/dispatch	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
merge-pattern-into-component	Merge pattern into component	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
evoluer-systeme-token	Évoluer système token	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
token-error-guidance	Token error guidance	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
token-role-mismatch	Token role mismatch	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
fix-gvp-intent-uri-double-prefix	Fix GVP intent URI double prefix	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
fix-intent-create-merge	Fix intent create merge	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
fix-intent-orphan-entity	Fix intent orphan entity	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
fix-task-refine-update	Fix task refine update	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
whatdo-task-delete	Whatdo task delete	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
whatis-extensions	Whatis extensions	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
task-auto-index	Task auto index	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
task-dependencies-ui	Task dependencies UI	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
trigger-sandbox	Trigger sandbox	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
domain-yaml-guideline	Domain YAML guideline	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
domain-scoped-tmux-sessions	Domain scoped tmux sessions	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
bootstrap-personal	Bootstrap personal domain	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
personal-domain-integration	Personal domain integration	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
break-circular-imports-bridge	Break circular imports bridge	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
rebranch-agent-panel	Rebranch agent panel	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
search-overlay-improvements	Search overlay improvements	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
ui-improve	UI improvements	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
fileexplorer-open	File explorer open	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
analysis-retry-tool	Analysis retry tool	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
audit-delegation	Audit delegation	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
autonomy-audit	Autonomy audit	\N	done	owner-1	2026-03-08 11:36:15.54586+00	2026-03-08 11:36:15.54586+00
agent-monitoring-ui	Agent monitoring UI	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
console-v2	Console v2	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
crd-entity-model-v2	CRD entity model v2	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
decouple-agent-manager	Decouple agent manager	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
facet-display-ux	Facet display UX	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
fix-say-to-answer	Fix say to answer	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
governance-enforcement-audit	Governance enforcement audit	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
implement-broker	Implement broker	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
personal-automation-scenarios	Personal automation scenarios	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
test-spawn	Test spawn	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
ui-ux-overhaul	UI/UX overhaul	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
uri-navigation-stack	URI navigation stack	\N	canceled	owner-1	2026-03-08 11:36:39.892416+00	2026-03-08 11:36:39.892416+00
\.


--
-- Data for Name: task; Type: TABLE DATA; Schema: organic; Owner: -
--

COPY organic.task (id, intent_id, name, description, state, assigned_to, result, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: shop; Owner: -
--

COPY shop.customers (id, name, email, created_at) FROM stdin;
1	Marie Dupont	marie@demo.com	2026-03-07 22:36:52.300178+00
2	Jean Martin	jean@demo.com	2026-03-07 22:36:52.300178+00
3	Sophie Bernard	sophie@demo.com	2026-03-07 22:36:52.300178+00
\.


--
-- Data for Name: discounts; Type: TABLE DATA; Schema: shop; Owner: -
--

COPY shop.discounts (code, kind, value, min_order, buy_x, get_y_free, active, expires_at) FROM stdin;
WELCOME10	percentage	10.00	50.00	\N	\N	t	\N
FLAT25	fixed	25.00	100.00	\N	\N	t	\N
B3G1	buy_x_get_y	0.00	0.00	3	1	t	\N
EXPIRED50	percentage	50.00	0.00	\N	\N	f	\N
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: shop; Owner: -
--

COPY shop.order_items (id, order_id, product_id, quantity, unit_price, subtotal) FROM stdin;
1	1	1	1	1299.00	1299.00
2	1	3	2	49.99	99.98
3	2	4	1	399.00	399.00
4	2	5	1	79.99	79.99
5	3	1	1	1299.00	1299.00
6	3	6	2	59.99	119.98
7	4	2	5	29.99	149.95
8	4	5	1	79.99	79.99
9	5	3	1	49.99	49.99
10	6	2	2	29.99	59.98
11	7	5	1	79.99	79.99
12	8	1	1	1299.00	1299.00
13	8	4	1	399.00	399.00
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: shop; Owner: -
--

COPY shop.orders (id, customer_id, status, subtotal, discount_amount, total, discount_code, created_at) FROM stdin;
1	1	confirmed	1398.98	139.90	1259.08	WELCOME10	2026-03-07 22:36:52.339572+00
2	2	confirmed	478.99	25.00	453.99	FLAT25	2026-03-07 22:36:52.342444+00
3	3	confirmed	1418.98	0.00	1418.98	\N	2026-03-07 22:36:52.343228+00
4	1	confirmed	229.94	4.60	225.34	\N	2026-03-07 22:36:52.343975+00
5	2	cancelled	49.99	0.00	49.99	\N	2026-03-07 22:36:52.344401+00
6	3	confirmed	59.98	1.20	58.78	\N	2026-03-07 22:37:50.035076+00
7	1	confirmed	79.99	1.60	78.39	\N	2026-03-07 22:38:33.164707+00
8	1	cancelled	1698.00	33.96	1664.04	\N	2026-03-07 23:23:45.513538+00
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: shop; Owner: -
--

COPY shop.products (id, name, price, stock) FROM stdin;
6	Webcam HD	59.99	28
3	USB-C Hub	49.99	48
2	Wireless Mouse	29.99	193
5	Keyboard	79.99	117
1	Laptop Pro	1299.00	13
4	Monitor 27"	399.00	7
\.


--
-- Name: event_id_seq; Type: SEQUENCE SET; Schema: organic; Owner: -
--

SELECT pg_catalog.setval('organic.event_id_seq', 8, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: shop; Owner: -
--

SELECT pg_catalog.setval('shop.customers_id_seq', 3, true);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: shop; Owner: -
--

SELECT pg_catalog.setval('shop.order_items_id_seq', 17, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: shop; Owner: -
--

SELECT pg_catalog.setval('shop.orders_id_seq', 14, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: shop; Owner: -
--

SELECT pg_catalog.setval('shop.products_id_seq', 6, true);


--
-- Name: agent agent_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.agent
    ADD CONSTRAINT agent_pkey PRIMARY KEY (id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (kind, id);


--
-- Name: entity_rel entity_rel_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.entity_rel
    ADD CONSTRAINT entity_rel_pkey PRIMARY KEY (from_kind, from_id, rel_type, to_kind, to_id);


--
-- Name: event event_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: intent intent_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.intent
    ADD CONSTRAINT intent_pkey PRIMARY KEY (id);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: customers customers_email_key; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.customers
    ADD CONSTRAINT customers_email_key UNIQUE (email);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: discounts discounts_pkey; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.discounts
    ADD CONSTRAINT discounts_pkey PRIMARY KEY (code);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: intent trg_intent_updated_at; Type: TRIGGER; Schema: organic; Owner: -
--

CREATE TRIGGER trg_intent_updated_at BEFORE UPDATE ON organic.intent FOR EACH ROW EXECUTE FUNCTION organic.trg_set_updated_at();


--
-- Name: task trg_task_assigned; Type: TRIGGER; Schema: organic; Owner: -
--

CREATE TRIGGER trg_task_assigned BEFORE UPDATE OF assigned_to ON organic.task FOR EACH ROW EXECUTE FUNCTION organic.trg_task_assigned();


--
-- Name: task trg_task_updated_at; Type: TRIGGER; Schema: organic; Owner: -
--

CREATE TRIGGER trg_task_updated_at BEFORE UPDATE ON organic.task FOR EACH ROW EXECUTE FUNCTION organic.trg_set_updated_at();


--
-- Name: entity_rel entity_rel_from_kind_from_id_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.entity_rel
    ADD CONSTRAINT entity_rel_from_kind_from_id_fkey FOREIGN KEY (from_kind, from_id) REFERENCES organic.entity(kind, id);


--
-- Name: entity_rel entity_rel_to_kind_to_id_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.entity_rel
    ADD CONSTRAINT entity_rel_to_kind_to_id_fkey FOREIGN KEY (to_kind, to_id) REFERENCES organic.entity(kind, id);


--
-- Name: event event_actor_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.event
    ADD CONSTRAINT event_actor_fkey FOREIGN KEY (actor) REFERENCES organic.agent(id);


--
-- Name: intent intent_created_by_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.intent
    ADD CONSTRAINT intent_created_by_fkey FOREIGN KEY (created_by) REFERENCES organic.agent(id);


--
-- Name: task task_assigned_to_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.task
    ADD CONSTRAINT task_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES organic.agent(id);


--
-- Name: task task_intent_id_fkey; Type: FK CONSTRAINT; Schema: organic; Owner: -
--

ALTER TABLE ONLY organic.task
    ADD CONSTRAINT task_intent_id_fkey FOREIGN KEY (intent_id) REFERENCES organic.intent(id);


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES shop.products(id);


--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: shop; Owner: -
--

ALTER TABLE ONLY shop.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES shop.customers(id);


--
-- PostgreSQL database dump complete
--

\unrestrict FLonl5zPFy3Rb4ckbvJiHZB5VZo3LiAld99JVVLhVGVLOIKjjjKUEJEgtjnq4jW

