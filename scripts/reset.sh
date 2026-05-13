#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root regardless of where the script is invoked from
cd "$(dirname "$0")/.."

REPO="hawk-yousef-matar/demo-e2e-release"
BASE_COMMIT="$(git rev-parse HEAD)"  # always reset to wherever main currently is after this commit

echo "Resetting demo to base state..."

# 1. Capture the latest version before deleting anything
LATEST_VERSION=$(gh release list --repo "$REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "1.0.0")
echo "→ Latest version: $LATEST_VERSION (will become new baseline)"

# 2. Delete all GitHub releases (--cleanup-tag removes the remote git tag too)
echo "→ Deleting GitHub releases..."
while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  echo "  deleting release $tag"
  gh release delete "$tag" --repo "$REPO" --yes --cleanup-tag 2>/dev/null || true
done < <(gh release list --repo "$REPO" --limit 100 --json tagName --jq '.[].tagName')

# 3. Clean up orphaned local tags
echo "→ Cleaning up local tags..."
while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  git tag -d "$tag" 2>/dev/null || true
done < <(git tag -l)

# 4. Clean up orphaned remote tags (in case --cleanup-tag missed any)
echo "→ Cleaning up remote tags..."
while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  git push origin --delete "refs/tags/$tag" 2>/dev/null || true
done < <(git ls-remote --tags origin 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||' | grep -v '\^{}')

# 5. Force-reset main to this commit (removes any setup commits)
echo "→ Resetting main to $BASE_COMMIT..."
git fetch origin
git checkout main
git reset --hard "$BASE_COMMIT"
git push origin main --force

# 6. Delete remote feature branches left over from setup
echo "→ Cleaning up remote feature branches..."
while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  echo "  deleting $branch"
  git push origin --delete "$branch" 2>/dev/null || true
done < <(git ls-remote --heads origin 2>/dev/null | awk '{print $2}' | sed 's|refs/heads/||' | grep -v '^main$')

# 7. Recreate the latest release at this commit (version keeps incrementing across runs)
echo "→ Recreating $LATEST_VERSION release at base commit..."
gh release create "$LATEST_VERSION" \
  --repo "$REPO" \
  --target "$BASE_COMMIT" \
  --title "$LATEST_VERSION" \
  --notes "Demo baseline." \
  --latest

echo ""
echo "✅ Reset complete."
echo "   main → $BASE_COMMIT | baseline release → $LATEST_VERSION"
echo ""
echo "Run: bash scripts/setup.sh"
