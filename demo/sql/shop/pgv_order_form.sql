CREATE OR REPLACE FUNCTION shop.pgv_order_form()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
$function$;
