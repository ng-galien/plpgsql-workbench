CREATE OR REPLACE FUNCTION document.canvas_render_svg_mini(p_canvas_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c document.canvas;
  v_svg text;
  v_defs text := '';
  v_attrs text;
  v_transform text;
  v_cx real; v_cy real;
  v_img_path text;
  v_img_mime text;
  v_object_fit text;
  v_nat_w real; v_nat_h real;
  v_crop_x real; v_crop_y real; v_crop_zoom real;
  v_base_scale real; v_scale real;
  v_img_w real; v_img_h real; v_img_x real; v_img_y real;
  r record;
BEGIN
  SELECT * INTO v_c FROM document.canvas WHERE id = p_canvas_id;
  IF v_c IS NULL THEN RETURN NULL; END IF;

  v_svg := '';
  v_svg := v_svg || '<rect width="' || v_c.width::text || '" height="' || v_c.height::text
    || '" fill="' || pgv.esc(v_c.background) || '"/>';

  FOR r IN
    SELECT * FROM document.element
    WHERE canvas_id = p_canvas_id
    ORDER BY sort_order
  LOOP
    v_attrs := '';
    IF r.opacity < 1 THEN v_attrs := v_attrs || ' opacity="' || r.opacity::text || '"'; END IF;
    IF r.stroke_dasharray IS NOT NULL THEN v_attrs := v_attrs || ' stroke-dasharray="' || pgv.esc(r.stroke_dasharray) || '"'; END IF;
    IF r.stroke_width IS NOT NULL THEN v_attrs := v_attrs || ' stroke-width="' || r.stroke_width::text || '"'; END IF;

    v_transform := '';
    IF r.rotation != 0 THEN
      CASE r.type
        WHEN 'rect', 'image', 'text' THEN
          v_cx := COALESCE(r.x, 0) + COALESCE(r.width, 0) / 2;
          v_cy := COALESCE(r.y, 0) + COALESCE(r.height, 0) / 2;
        WHEN 'circle' THEN v_cx := r.cx; v_cy := r.cy;
        WHEN 'ellipse' THEN v_cx := r.cx; v_cy := r.cy;
        WHEN 'line' THEN v_cx := (r.x1 + r.x2) / 2; v_cy := (r.y1 + r.y2) / 2;
        ELSE v_cx := 0; v_cy := 0;
      END CASE;
      v_transform := ' transform="rotate(' || r.rotation::text || ',' || v_cx::text || ',' || v_cy::text || ')"';
    END IF;

    CASE r.type
      WHEN 'rect' THEN
        v_svg := v_svg || '<rect x="' || r.x::text || '" y="' || r.y::text
          || '" width="' || r.width::text || '" height="' || r.height::text || '"'
          || CASE WHEN r.fill IS NOT NULL THEN ' fill="' || pgv.esc(r.fill) || '"' ELSE '' END
          || CASE WHEN r.stroke IS NOT NULL THEN ' stroke="' || pgv.esc(r.stroke) || '"' ELSE '' END
          || CASE WHEN r.rx_ IS NOT NULL THEN ' rx="' || r.rx_::text || '"' ELSE '' END
          || CASE WHEN (r.props->>'borderRadius') IS NOT NULL THEN ' rx="' || pgv.esc(r.props->>'borderRadius') || '"' ELSE '' END
          || v_attrs || v_transform || '/>';
      WHEN 'text' THEN
        v_svg := v_svg || '<text x="' || r.x::text || '" y="' || r.y::text || '"'
          || CASE WHEN r.fill IS NOT NULL THEN ' fill="' || pgv.esc(r.fill) || '"' ELSE '' END
          || ' font-size="' || COALESCE((r.props->>'fontSize')::text, '12') || '"'
          || CASE WHEN r.props->>'fontWeight' = 'bold' THEN ' font-weight="bold"' ELSE '' END
          || CASE WHEN r.props->>'fontStyle' = 'italic' THEN ' font-style="italic"' ELSE '' END
          || CASE WHEN r.props->>'textAnchor' IS NOT NULL THEN ' text-anchor="' || pgv.esc(r.props->>'textAnchor') || '"' ELSE '' END
          || v_attrs || v_transform
          || '>' || pgv.esc(COALESCE(r.props->>'content', '')) || '</text>';
      WHEN 'line' THEN
        v_svg := v_svg || '<line x1="' || r.x1::text || '" y1="' || r.y1::text
          || '" x2="' || r.x2::text || '" y2="' || r.y2::text || '"'
          || ' stroke="' || COALESCE(pgv.esc(r.stroke), '#000') || '"'
          || v_attrs || v_transform || '/>';
      WHEN 'circle' THEN
        v_svg := v_svg || '<circle cx="' || r.cx::text || '" cy="' || r.cy::text
          || '" r="' || r.r::text || '"'
          || CASE WHEN r.fill IS NOT NULL THEN ' fill="' || pgv.esc(r.fill) || '"' ELSE '' END
          || CASE WHEN r.stroke IS NOT NULL THEN ' stroke="' || pgv.esc(r.stroke) || '"' ELSE '' END
          || v_attrs || v_transform || '/>';
      WHEN 'ellipse' THEN
        v_svg := v_svg || '<ellipse cx="' || r.cx::text || '" cy="' || r.cy::text
          || '" rx="' || r.rx_::text || '" ry="' || r.ry_::text || '"'
          || CASE WHEN r.fill IS NOT NULL THEN ' fill="' || pgv.esc(r.fill) || '"' ELSE '' END
          || CASE WHEN r.stroke IS NOT NULL THEN ' stroke="' || pgv.esc(r.stroke) || '"' ELSE '' END
          || v_attrs || v_transform || '/>';
      WHEN 'image' THEN
        v_img_path := NULL;
        v_img_mime := NULL;
        IF r.asset_id IS NOT NULL THEN
          SELECT a.path, a.mime_type INTO v_img_path, v_img_mime FROM asset.asset a WHERE a.id = r.asset_id;
        END IF;
        IF v_img_path IS NOT NULL THEN
          v_object_fit := COALESCE(r.props->>'objectFit', 'cover');

          IF v_img_mime = 'image/svg+xml' OR v_object_fit = 'contain' THEN
            -- SVG or contain: preserve aspect ratio, no crop
            v_svg := v_svg || '<image href="' || pgv.esc(v_img_path) || '"'
              || ' x="' || r.x::text || '" y="' || r.y::text
              || '" width="' || r.width::text || '" height="' || r.height::text || '"'
              || ' preserveAspectRatio="xMidYMid meet"'
              || v_attrs || v_transform || '/>';
          ELSIF r.props->>'naturalWidth' IS NOT NULL THEN
            -- Crop cover with clipPath
            v_nat_w := (r.props->>'naturalWidth')::real;
            v_nat_h := (r.props->>'naturalHeight')::real;
            v_crop_x := COALESCE((r.props->>'cropX')::real, 0.5);
            v_crop_y := COALESCE((r.props->>'cropY')::real, 0.5);
            v_crop_zoom := COALESCE((r.props->>'cropZoom')::real, 1.0);
            v_base_scale := greatest(r.width / v_nat_w, r.height / v_nat_h);
            v_scale := v_base_scale * v_crop_zoom;
            v_img_w := v_nat_w * v_scale;
            v_img_h := v_nat_h * v_scale;
            v_img_x := r.x - (v_img_w - r.width) * v_crop_x;
            v_img_y := r.y - (v_img_h - r.height) * v_crop_y;

            v_defs := v_defs || '<clipPath id="c_' || r.id::text || '">'
              || '<rect x="' || r.x::text || '" y="' || r.y::text
              || '" width="' || r.width::text || '" height="' || r.height::text || '"/>'
              || '</clipPath>';

            v_svg := v_svg || '<g clip-path="url(#c_' || r.id::text || ')"' || v_attrs || v_transform || '>'
              || '<image href="' || pgv.esc(v_img_path) || '"'
              || ' x="' || v_img_x::text || '" y="' || v_img_y::text
              || '" width="' || v_img_w::text || '" height="' || v_img_h::text
              || '" preserveAspectRatio="none"/></g>';
          ELSE
            -- Fallback: slice
            v_svg := v_svg || '<image href="' || pgv.esc(v_img_path) || '"'
              || ' x="' || r.x::text || '" y="' || r.y::text
              || '" width="' || r.width::text || '" height="' || r.height::text || '"'
              || ' preserveAspectRatio="xMidYMid slice"'
              || v_attrs || v_transform || '/>';
          END IF;
        ELSE
          v_svg := v_svg || '<rect x="' || r.x::text || '" y="' || r.y::text
            || '" width="' || r.width::text || '" height="' || r.height::text
            || '" fill="#ddd"' || v_attrs || v_transform || '/>';
        END IF;
      WHEN 'path' THEN
        IF r.props ? 'd' THEN
          v_svg := v_svg || '<path d="' || pgv.esc(r.props->>'d') || '"'
            || CASE WHEN r.fill IS NOT NULL THEN ' fill="' || pgv.esc(r.fill) || '"' ELSE ' fill="none"' END
            || CASE WHEN r.stroke IS NOT NULL THEN ' stroke="' || pgv.esc(r.stroke) || '"' ELSE '' END
            || v_attrs || v_transform || '/>';
        END IF;
      ELSE
        NULL;
    END CASE;
  END LOOP;

  RETURN '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 '
    || v_c.width::text || ' ' || v_c.height::text || '">'
    || CASE WHEN v_defs != '' THEN '<defs>' || v_defs || '</defs>' ELSE '' END
    || v_svg || '</svg>';
END;
$function$;
