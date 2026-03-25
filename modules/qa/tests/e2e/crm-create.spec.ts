import { test, expect } from "@playwright/test";

test.describe("CRM client creation via overlay", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.waitForSelector("[data-debug='sidebar']", { timeout: 10_000 });
  });

  test("create a client via overlay form", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Wait for list to load
    await expect(
      page.locator("[data-debug^='overlay.item[crm://client/']").first()
    ).toBeVisible({ timeout: 5_000 });
    const initialCount = await page
      .locator("[data-debug^='overlay.item[crm://client/']")
      .count();

    // Click "+ Nouveau" button
    const newBtn = overlay.locator("button", { hasText: /Nouveau|New/ });
    await expect(newBtn).toBeVisible();
    await newBtn.click();

    // Form should appear with a back arrow
    await expect(overlay.locator("svg.lucide-arrow-left").first()).toBeVisible({
      timeout: 3_000,
    });

    // Fill required "type" select (NOT NULL constraint)
    const typeSelect = overlay.locator("select").first();
    await typeSelect.selectOption({ index: 1 }); // first non-empty option

    // Fill required name field
    const nameInput = overlay.locator("input[type='text']").first();
    await nameInput.fill("QA Test Client E2E");

    // Submit the form
    const saveBtn = overlay.locator("button", { hasText: /Save|Enregistrer/ });
    await saveBtn.click();

    // After creation, it should auto-pin and go back to list mode
    // The new card should appear on canvas
    const card = page.locator("[data-debug^='canvas.pin[crm://client/']");
    await expect(card.first()).toBeVisible({ timeout: 8_000 });

    // The card should contain the name we entered
    await expect(card.first().locator("text=QA Test Client E2E")).toBeVisible();
  });

  test("form validation rejects empty name", async ({ page }) => {
    const clientBtn = page.locator("[data-debug='sidebar.item[crm://client]']");
    await clientBtn.click();

    const overlay = page.locator("[data-debug^='overlay[crm://client]']");
    await expect(overlay).toBeVisible({ timeout: 5_000 });

    // Wait for list then click new
    await expect(
      page.locator("[data-debug^='overlay.item[crm://client/']").first()
    ).toBeVisible({ timeout: 5_000 });

    const newBtn = overlay.locator("button", { hasText: /Nouveau|New/ });
    await newBtn.click();

    // Don't fill anything, just submit
    const saveBtn = overlay.locator("button", { hasText: /Save|Enregistrer/ });
    await saveBtn.click();

    // Should show error message div (not the * required markers)
    const error = overlay.locator("div.text-destructive");
    await expect(error).toBeVisible({ timeout: 3_000 });
    const errorText = await error.textContent();
    expect(errorText).toBeTruthy();
    expect(errorText!.length).toBeGreaterThan(5);
  });
});
