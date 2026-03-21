CREATE OR REPLACE FUNCTION document.xhtml_patch(p_html text, p_ops jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text := p_html;
  v_op jsonb;
  v_id text;
  v_marker text;
  v_pos int;
  v_tag_start int;
  v_tag_end int;
  v_close_pos int;
  v_tag_name text;
  v_old_style text;
  v_new_style text;
  v_style_str text;
  v_sk text;
  v_sv text;
  v_depth int;
  v_search_pos int;
  v_elem_start int;
  v_elem_end int;
  v_inner_start int;
  v_self_closing boolean;
BEGIN
  FOR v_op IN SELECT value FROM jsonb_array_elements(p_ops)
  LOOP
    v_id := v_op->>'id';
    v_marker := 'data-id="' || v_id || '"';
    v_pos := position(v_marker in v_html);
    IF v_pos = 0 THEN CONTINUE; END IF;

    -- Find the opening tag boundaries: scan backwards for '<'
    v_tag_start := v_pos;
    WHILE v_tag_start > 1 AND substr(v_html, v_tag_start, 1) != '<' LOOP
      v_tag_start := v_tag_start - 1;
    END LOOP;

    -- Extract tag name
    v_tag_name := (regexp_match(substr(v_html, v_tag_start), '^<([a-zA-Z][a-zA-Z0-9]*)'))[1];

    -- Find end of opening tag
    v_tag_end := position('>' in substr(v_html, v_tag_start)) + v_tag_start - 1;

    -- Check self-closing
    v_self_closing := substr(v_html, v_tag_end - 1, 2) = '/>';

    IF NOT v_self_closing THEN
      -- Find matching closing tag (handle nesting)
      v_inner_start := v_tag_end + 1;
      v_depth := 1;
      v_search_pos := v_inner_start;
      WHILE v_depth > 0 AND v_search_pos <= length(v_html) LOOP
        -- Look for next opening or closing tag of same name
        v_close_pos := position('</' || v_tag_name in substr(v_html, v_search_pos));
        IF v_close_pos = 0 THEN EXIT; END IF;
        v_close_pos := v_close_pos + v_search_pos - 1;

        -- Check for nested opening tags between search_pos and close_pos
        DECLARE
          v_nested_pos int;
          v_scan int := v_search_pos;
        BEGIN
          LOOP
            v_nested_pos := position('<' || v_tag_name in substr(v_html, v_scan));
            IF v_nested_pos = 0 THEN EXIT; END IF;
            v_nested_pos := v_nested_pos + v_scan - 1;
            IF v_nested_pos >= v_close_pos THEN EXIT; END IF;
            -- Verify it's actually an opening tag (not </tag or part of another tag)
            IF substr(v_html, v_nested_pos + 1 + length(v_tag_name), 1) IN (' ', '>', '/') THEN
              v_depth := v_depth + 1;
            END IF;
            v_scan := v_nested_pos + 1;
          END LOOP;
        END;

        v_depth := v_depth - 1;
        IF v_depth = 0 THEN
          -- v_close_pos is the start of the closing tag
          v_elem_end := position('>' in substr(v_html, v_close_pos)) + v_close_pos; -- after '>'
        ELSE
          v_search_pos := v_close_pos + 1;
        END IF;
      END LOOP;
    ELSE
      v_inner_start := v_tag_end; -- no inner content
      v_elem_end := v_tag_end + 1;
    END IF;

    -- REMOVE
    IF (v_op->>'remove')::boolean IS TRUE THEN
      v_html := substr(v_html, 1, v_tag_start - 1) || substr(v_html, v_elem_end);
      CONTINUE;
    END IF;

    -- REPLACE (outer)
    IF v_op ? 'replace' THEN
      v_html := substr(v_html, 1, v_tag_start - 1) || (v_op->>'replace') || substr(v_html, v_elem_end);
      CONTINUE;
    END IF;

    -- STYLE merge
    IF v_op ? 'style' THEN
      -- Build new style string from op
      v_style_str := '';
      FOR v_sk, v_sv IN SELECT key, value #>> '{}' FROM jsonb_each(v_op->'style')
      LOOP
        IF v_style_str != '' THEN v_style_str := v_style_str || ';'; END IF;
        v_style_str := v_style_str || v_sk || ':' || v_sv;
      END LOOP;

      -- Extract existing style from opening tag
      DECLARE
        v_open_tag text := substr(v_html, v_tag_start, v_tag_end - v_tag_start + 1);
        v_style_match text[];
        v_new_tag text;
      BEGIN
        v_style_match := regexp_match(v_open_tag, 'style="([^"]*)"');
        IF v_style_match IS NOT NULL THEN
          v_old_style := v_style_match[1];
          v_new_style := document.style_merge(v_old_style, v_style_str);
          v_new_tag := regexp_replace(v_open_tag, 'style="[^"]*"', 'style="' || v_new_style || '"');
        ELSE
          -- No existing style, add it before the closing > or />
          IF v_self_closing THEN
            v_new_tag := regexp_replace(v_open_tag, '\s*/>', ' style="' || v_style_str || '"/>');
          ELSE
            v_new_tag := regexp_replace(v_open_tag, '>', ' style="' || v_style_str || '">');
          END IF;
        END IF;
        v_html := substr(v_html, 1, v_tag_start - 1) || v_new_tag || substr(v_html, v_tag_end + 1);

        -- Adjust positions after tag replacement
        v_tag_end := v_tag_start + length(v_new_tag) - 1;
        v_inner_start := v_tag_end + 1;
      END;
    END IF;

    -- CONTENT (innerHTML replacement)
    IF v_op ? 'content' AND NOT v_self_closing THEN
      -- Recalculate close position after potential style change
      v_close_pos := position('</' || v_tag_name in substr(v_html, v_inner_start));
      IF v_close_pos > 0 THEN
        v_close_pos := v_close_pos + v_inner_start - 1;
        v_html := substr(v_html, 1, v_inner_start - 1) || (v_op->>'content') || substr(v_html, v_close_pos);
      END IF;
    END IF;

    -- INSERT (beforeend = before closing tag)
    IF v_op ? 'insert' AND NOT v_self_closing THEN
      v_close_pos := position('</' || v_tag_name in substr(v_html, v_inner_start));
      IF v_close_pos > 0 THEN
        v_close_pos := v_close_pos + v_inner_start - 1;
        v_html := substr(v_html, 1, v_close_pos - 1) || (v_op->>'insert') || substr(v_html, v_close_pos);
      END IF;
    END IF;
  END LOOP;

  -- Validate result
  IF NOT document.xhtml_validate(v_html) THEN
    RAISE EXCEPTION 'xhtml_patch produced invalid XML';
  END IF;

  RETURN v_html;
END;
$function$;
