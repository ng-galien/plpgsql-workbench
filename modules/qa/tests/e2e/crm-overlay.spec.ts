import { test, expect } from "@playwright/test";

test.describe("CRM overlay and pinning", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.waitForSelector("[data-debug='sidebar']", { timeout: 10_000 });
  });

  test("open CRM client overlay and list items", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await expect(clientBtn).toBeVisible();
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Should have at least one item loaded
    const items = page.locator("[data-debug^='overlay.item[crm://client/']");
    await expect(items.first()).toBeVisible({ timeout: 5_000 });
    const count = await items.count();
    expect(count).toBeGreaterThan(0);
  });

  test("pin client and verify card renders with template fields", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    const item = page.locator("[data-debug^='overlay.item[crm://client/']").first();
    await expect(item).toBeVisible({ timeout: 5_000 });

    // Get the item's name before pinning
    const itemName = await item.locator(".font-medium").textContent();
    expect(itemName).toBeTruthy();

    await item.click();

    // Card should appear on canvas
    const card = page.locator("[data-debug^='canvas.pin[crm://client/']").first();
    await expect(card).toBeVisible({ timeout: 5_000 });

    // Card should show the client name
    const cardName = await card.locator(".font-semibold").textContent();
    expect(cardName).toBe(itemName);

    // Card should have template fields (key-value pairs from _view)
    const fields = card.locator(".text-muted-foreground.text-xs");
    const fieldCount = await fields.count();
    expect(fieldCount).toBeGreaterThan(0);
  });

  test("overlay search filters items", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Wait for items to load
    const items = page.locator("[data-debug^='overlay.item[crm://client/']");
    await expect(items.first()).toBeVisible({ timeout: 5_000 });
    const initialCount = await items.count();

    // Type a nonsense search to filter to zero
    const searchInput = overlay.locator("input[type='text']");
    await searchInput.fill("zzz_no_match_999");
    await page.waitForTimeout(300);

    // Should show "No results."
    await expect(overlay.locator("text=No results.")).toBeVisible();

    // Clear search to restore
    await searchInput.clear();
    await page.waitForTimeout(300);
    const restored = await items.count();
    expect(restored).toBe(initialCount);
  });

  test("close overlay via backdrop click", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Click backdrop (the bg-black/5 div)
    await page.locator(".bg-black\\/5").click();
    await expect(overlay).not.toBeVisible();
  });
});
