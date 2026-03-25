import { test, expect } from "@playwright/test";

test.describe("Shell workspace", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.waitForSelector("[data-debug='sidebar']", { timeout: 10_000 });
  });

  test("sidebar loads with modules", async ({ page }) => {
    const buttons = page.locator("[data-debug^='sidebar.item']");
    await expect(buttons.first()).toBeVisible();
    const count = await buttons.count();
    expect(count).toBeGreaterThan(5);
  });

  test("clicking sidebar item opens overlay", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    if (await clientBtn.isVisible()) {
      await clientBtn.click();
      const overlay = page.locator("[data-debug='overlay[crm://client]']");
      await expect(overlay).toBeVisible({ timeout: 5_000 });
    }
  });

  test("overlay lists items and allows pinning", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    if (!(await clientBtn.isVisible())) return;

    await clientBtn.click();
    const overlay = page.locator("[data-debug='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Wait for items to load
    const item = page.locator("[data-debug^='overlay.item']").first();
    await expect(item).toBeVisible({ timeout: 5_000 });

    // Pin an item
    await item.click();

    // Check canvas has a pinned card
    const card = page.locator("[data-debug^='canvas.pin']").first();
    await expect(card).toBeVisible({ timeout: 5_000 });
  });

  test("annotation mode activates with Ctrl+Shift+A", async ({ page }) => {
    await page.keyboard.press("Control+Shift+A");
    const indicator = page.locator("text=Report mode");
    await expect(indicator).toBeVisible({ timeout: 2_000 });

    // Deactivate
    await page.keyboard.press("Control+Shift+A");
    await expect(indicator).not.toBeVisible();
  });
});
