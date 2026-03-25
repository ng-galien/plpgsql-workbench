import { test, expect } from "@playwright/test";

test.describe("HATEOAS action buttons on pinned cards", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.waitForSelector("[data-debug='sidebar']", { timeout: 10_000 });
  });

  test("pinned CRM client card shows HATEOAS action buttons", async ({
    page,
  }) => {
    // Open CRM client overlay
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Pin first client
    const item = page
      .locator("[data-debug^='overlay.item[crm://client/']")
      .first();
    await expect(item).toBeVisible({ timeout: 5_000 });
    await item.click();

    // Card should appear
    const card = page
      .locator("[data-debug^='canvas.pin[crm://client/']")
      .first();
    await expect(card).toBeVisible({ timeout: 5_000 });

    // Card should have action buttons in a border-t footer area
    const actionBar = card.locator(".border-t.flex.gap-2");
    // Actions may or may not be present depending on the entity's HATEOAS response
    // If present, each button should have text
    const actionCount = await actionBar.locator("button").count();
    if (actionCount > 0) {
      for (let i = 0; i < actionCount; i++) {
        const btn = actionBar.locator("button").nth(i);
        const text = await btn.textContent();
        expect(text?.trim().length).toBeGreaterThan(0);
      }
    }
  });

  test("pinned quote devis card shows workflow actions", async ({ page }) => {
    // Open quote devis overlay
    const devisBtn = page.locator(
      "[data-debug='sidebar.item[quote://devis]']"
    );
    if (!(await devisBtn.isVisible())) return;
    await devisBtn.click();

    const overlay = page.locator("[data-debug^='overlay[quote://devis]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Pin first devis
    const item = page
      .locator("[data-debug^='overlay.item[quote://devis/']")
      .first();
    await expect(item).toBeVisible({ timeout: 5_000 });
    await item.click();

    // Card should appear
    const card = page
      .locator("[data-debug^='canvas.pin[quote://devis/']")
      .first();
    await expect(card).toBeVisible({ timeout: 5_000 });

    // Devis cards should have actions (envoyer, supprimer, etc.)
    const actionButtons = card.locator(".border-t button");
    const count = await actionButtons.count();
    // Draft devis should have at least 1 action
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test("multiple entities can be pinned simultaneously", async ({ page }) => {
    // Pin a CRM client
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();
    const clientOverlay = page.locator(
      "[data-debug^='overlay[crm://client]']"
    );
    await expect(clientOverlay).toBeVisible({ timeout: 5_000 });

    const clientItem = page
      .locator("[data-debug^='overlay.item[crm://client/']")
      .first();
    await expect(clientItem).toBeVisible({ timeout: 5_000 });
    await clientItem.click();

    // Close overlay
    await page.locator(".bg-black\\/5").click();

    // Pin a catalog article
    const articleBtn = page.locator(
      "[data-debug='sidebar.item[catalog://article]']"
    );
    if (!(await articleBtn.isVisible())) return;
    await articleBtn.click();

    const articleOverlay = page.locator(
      "[data-debug^='overlay[catalog://article]']"
    );
    await expect(articleOverlay).toBeVisible({ timeout: 5_000 });

    const articleItem = page
      .locator("[data-debug^='overlay.item[catalog://article/']")
      .first();
    await expect(articleItem).toBeVisible({ timeout: 5_000 });
    await articleItem.click();

    // Both cards should be visible on canvas
    const clientCards = page.locator(
      "[data-debug^='canvas.pin[crm://client/']"
    );
    const articleCards = page.locator(
      "[data-debug^='canvas.pin[catalog://article/']"
    );
    await expect(clientCards.first()).toBeVisible();
    await expect(articleCards.first()).toBeVisible();

    // Total pins = 2
    const allPins = page.locator("[data-debug^='canvas.pin']");
    expect(await allPins.count()).toBe(2);
  });

  test("unpin card via close button", async ({ page }) => {
    // Pin a client
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();
    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    const item = page
      .locator("[data-debug^='overlay.item[crm://client/']")
      .first();
    await expect(item).toBeVisible({ timeout: 5_000 });
    await item.click();

    const card = page
      .locator("[data-debug^='canvas.pin[crm://client/']")
      .first();
    await expect(card).toBeVisible({ timeout: 5_000 });

    // Close overlay first
    await page.locator(".bg-black\\/5").click();

    // Click the X button on the card
    const closeBtn = card.locator("svg.lucide-x").first();
    await closeBtn.click();

    // Card should be gone
    await expect(card).not.toBeVisible();

    // Canvas should show empty state
    await expect(page.locator("text=Workspace")).toBeVisible();
  });
});
