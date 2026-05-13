// run 1778686458
describe("ERD", () => {
  it("renders entity relationship diagram", async () => {
    await page.goto("/erd");
    await expect(page.locator(".erd-canvas")).toBeVisible();
  });
});
