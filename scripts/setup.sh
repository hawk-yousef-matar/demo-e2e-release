#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root regardless of where the script is invoked from
cd "$(dirname "$0")/.."

REPO="hawk-yousef-matar/demo-e2e-release"

echo "Setting up demo PRs..."

# Ensure version labels exist
echo "→ Ensuring version labels..."
gh label create "patch-version"  --repo "$REPO" --color "0075ca" --description "Bump patch version"  2>/dev/null || true
gh label create "minor-version"  --repo "$REPO" --color "e4e669" --description "Bump minor version"  2>/dev/null || true
gh label create "major-version"  --repo "$REPO" --color "d73a4a" --description "Bump major version"  2>/dev/null || true

# Clean up any leftover local branches from a previous failed run
for branch in fix/correct-typo-in-config feat/add-erd-e2e-tests feat/migrate-to-playwright; do
  git branch -D "$branch" 2>/dev/null || true
done

git checkout main
git pull origin main

# ── PR 1: patch ───────────────────────────────────────────────────────────────
echo "→ PR 1 (patch): Fix typo in e2e config"
git checkout -b fix/correct-typo-in-config

cat > e2e.config.js << 'EOF'
module.exports = {
  baseUrl: "https://app.hawk.ai",
  timeout: 30000,
};
EOF

git add e2e.config.js
git commit -m "fix: correct typo in e2e config"
git push origin fix/correct-typo-in-config
git checkout main

gh pr create \
  --repo "$REPO" \
  --title "Fix typo in e2e config" \
  --body "Fixes a typo in the e2e configuration file." \
  --base main \
  --head fix/correct-typo-in-config \
  --label "patch-version"

PR1=$(gh pr view fix/correct-typo-in-config --repo "$REPO" --json number --jq '.number')
gh pr merge "$PR1" --repo "$REPO" --squash --delete-branch
git branch -D fix/correct-typo-in-config 2>/dev/null || true
git pull origin main
echo "  ✓ PR #$PR1 merged (patch)"

# ── PR 2: minor ───────────────────────────────────────────────────────────────
echo "→ PR 2 (minor): Add ERD e2e test suite"
git checkout -b feat/add-erd-e2e-tests

mkdir -p tests
cat > tests/erd.spec.js << 'EOF'
describe("ERD", () => {
  it("renders entity relationship diagram", async () => {
    await page.goto("/erd");
    await expect(page.locator(".erd-canvas")).toBeVisible();
  });
});
EOF

git add tests/erd.spec.js
git commit -m "feat: add ERD e2e test suite"
git push origin feat/add-erd-e2e-tests
git checkout main

gh pr create \
  --repo "$REPO" \
  --title "Add ERD e2e test suite" \
  --body "Adds end-to-end tests for the entity relationship diagram." \
  --base main \
  --head feat/add-erd-e2e-tests \
  --label "minor-version"

PR2=$(gh pr view feat/add-erd-e2e-tests --repo "$REPO" --json number --jq '.number')
gh pr merge "$PR2" --repo "$REPO" --squash --delete-branch
git branch -D feat/add-erd-e2e-tests 2>/dev/null || true
git pull origin main
echo "  ✓ PR #$PR2 merged (minor)"

# ── PR 3: major ───────────────────────────────────────────────────────────────
echo "→ PR 3 (major): Migrate test runner to Playwright"
git checkout -b feat/migrate-to-playwright

cat > playwright.config.js << 'EOF'
module.exports = {
  testDir: "./tests",
  use: {
    headless: true,
    baseURL: "https://app.hawk.ai",
  },
};
EOF

git add playwright.config.js
git commit -m "feat!: migrate test runner to Playwright"
git push origin feat/migrate-to-playwright
git checkout main

gh pr create \
  --repo "$REPO" \
  --title "Migrate test runner to Playwright" \
  --body "Breaking change: replaces the existing test runner with Playwright." \
  --base main \
  --head feat/migrate-to-playwright \
  --label "major-version"

PR3=$(gh pr view feat/migrate-to-playwright --repo "$REPO" --json number --jq '.number')
gh pr merge "$PR3" --repo "$REPO" --squash --delete-branch
git branch -D feat/migrate-to-playwright 2>/dev/null || true
git pull origin main
echo "  ✓ PR #$PR3 merged (major)"

echo ""
echo "✅ Setup complete. 3 PRs created and merged."
echo "   #$PR1 patch → #$PR2 minor → #$PR3 major"
echo ""
echo "Run /release-e2e-demo to create the releases."
