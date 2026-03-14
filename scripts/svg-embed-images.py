#!/usr/bin/env python3
"""Embed local images into SVG as base64 data URIs."""
import re, base64, mimetypes, sys

svg_path = sys.argv[1]
img_root = sys.argv[2] if len(sys.argv) > 2 else "dev/frontend"

svg = open(svg_path).read()

def repl(m):
    rel = m.group(1)
    path = img_root + rel
    try:
        data = open(path, "rb").read()
        mt = mimetypes.guess_type(path)[0] or "image/png"
        b64 = base64.b64encode(data).decode()
        return f'href="data:{mt};base64,{b64}"'
    except FileNotFoundError:
        return m.group(0)

svg = re.sub(r'href="(/images/[^"]+)"', repl, svg)
open(svg_path, "w").write(svg)
