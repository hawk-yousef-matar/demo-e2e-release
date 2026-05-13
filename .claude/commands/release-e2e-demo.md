---
name: release-e2e-demo
description: Demo version of release-e2e targeting hawk-yousef-matar/demo-e2e-release. Create GitHub releases for untagged commits on main, detecting PR version labels (patch-version, minor-version, major-version).
---

# Release E2E Tests (Demo)

Create GitHub releases for all untagged commits on main in `hawk-yousef-matar/demo-e2e-release`, following the team's release process.

## Step 1: Get the latest release

```bash
gh api repos/hawk-yousef-matar/demo-e2e-release/releases --jq '.[0] | "\(.tag_name)"'
```

Parse the version into MAJOR.MINOR.PATCH components. Validate that the tag matches the `X.Y.Z` semver format. If it doesn't, abort with a clear error.

## Step 2: Find untagged commits on main since the last release

```bash
gh api "repos/hawk-yousef-matar/demo-e2e-release/compare/<LATEST_TAG>...main" --jq '{total_commits: .total_commits, commits: [.commits[] | {sha: .sha, message: (.commit.message | split("\n")[0]), author: .author.login, date: .commit.author.date}]}'
```

This gives all commits on main that haven't been released yet, in chronological order (oldest first).

**Pagination:** Check if `total_commits` exceeds the number of commits returned. If so, paginate:

```bash
gh api "repos/hawk-yousef-matar/demo-e2e-release/compare/<LATEST_TAG>...main?per_page=100&page=N"
```

Collect all pages until all commits are gathered. If `total_commits` > 500, warn the user about the large gap and ask whether to proceed.

If there are no untagged commits (`total_commits == 0`), inform the user that everything is already released and stop.

## Step 3: Resolve PR details for each commit

For each commit, extract the PR number using this priority:

1. **Regex match**: look for `(#NNNN)` at the end of the first line of the commit message
2. **Fallback**: if no PR number found, use:
   ```bash
   gh pr list --repo hawk-yousef-matar/demo-e2e-release --search "<COMMIT_SHA>" --state merged --json number --jq '.[0].number'
   ```
3. **Last resort**: if no PR is found at all (direct push), mark as "no PR" and default to `patch-version`

For each resolved PR, fetch labels and metadata:

```bash
gh pr view <PR_NUMBER> --repo hawk-yousef-matar/demo-e2e-release --json labels,title,author --jq '{title: .title, author: .author.login, labels: [.labels[].name]}'
```

Map the version label:
- `patch-version` → increment PATCH (e.g., 1.0.0 → 1.0.1)
- `minor-version` → increment MINOR, reset PATCH (e.g., 1.0.1 → 1.1.0)
- `major-version` → increment MAJOR, reset MINOR and PATCH (e.g., 1.1.0 → 2.0.0)

If no version label is found, **default to PATCH**.

If multiple commits share the same PR number, each commit still gets its own release with the same version label applied.

## Step 4: Preview and confirm

Calculate the version sequence (cumulative bumps, oldest first) and present a preview table:

```
## Release Preview

| # | Version | SHA (short) | PR | Title | Author | Type |
|---|---------|-------------|-----|-------|--------|------|
| 1 | 1.0.1 | ff3bd18 | #1 | Fix typo in e2e config | @yousef | patch |
| 2 | 1.1.0 | abc1234 | #2 | Add ERD e2e test suite | @yousef | minor |
| 3 | 2.0.0 | def5678 | #3 | Migrate test runner to Playwright | @yousef | major |

**Summary:** 3 release(s) will be created, advancing from 1.0.0 → 2.0.0.
```

Flag warnings:
- Commits without a PR number (defaulting to patch)
- PRs with missing version labels (defaulting to patch)
- Any minor/major version bumps (highlight them)

**STOP HERE and wait for user confirmation.** Ask:
- "Shall I proceed with creating these release(s)?"
- "Would you like to skip any commits or change any version types?"

Only proceed after explicit user approval.

## Step 5: Create releases in order

For each commit (oldest to newest), create a release:

```bash
gh release create <NEW_VERSION> \
  --repo hawk-yousef-matar/demo-e2e-release \
  --target <FULL_COMMIT_SHA> \
  --title "<NEW_VERSION>" \
  --generate-notes \
  --notes-start-tag <PREVIOUS_VERSION> \
  --latest
```

Where `<PREVIOUS_VERSION>` is the tag immediately before this one (the original latest release for the first commit, or the just-created tag for subsequent ones).

**Important rules:**
- Always release in chronological order (oldest untagged commit first)
- Each commit gets its own release
- Version increments are cumulative (each release builds on the previous version number)
- Use `--latest` so each successive release is marked as the latest

## Step 6: Summary and next steps

After all releases are created, present:

```
## Releases Created

| Version | Commit | PR | Title | Author | Type |
|---------|--------|-----|-------|--------|------|
| 1.0.1 | ff3bd18 | #1 | Fix typo in e2e config | @yousef | patch |
| 1.1.0 | abc1234 | #2 | Add ERD e2e test suite | @yousef | minor |
| 2.0.0 | def5678 | #3 | Migrate test runner to Playwright | @yousef | major |

**Total:** 3 release(s) created. New latest version: 2.0.0
```

## Error handling

- **No untagged commits**: Inform user everything is released. Stop.
- **Pagination needed**: If `total_commits > commits.length`, paginate with `per_page=100`. If > 500 total, warn the user and ask to proceed.
- **PR not found for commit**: Default to patch, log a clear warning with the commit SHA and message.
- **Missing version label on PR**: Default to patch, log warning.
- **Release creation timeout/failure**: If `gh release create` fails but the tag already exists on retry check, it succeeded — skip and continue. If it fails with 422 "tag already exists" (from a previous partial run), skip gracefully and continue with remaining releases.
- **Rate limiting**: If API calls return 429 or secondary rate limit errors, pause and inform the user.
- **Partial completion**: If some releases succeed and others fail, report what was created and what remains, so the user can re-run the skill for the remainder.

## Anti-patterns

- **Do not create releases without user confirmation** — always present the preview first and wait for explicit approval, regardless of how trivial the releases appear.
- **Do not skip commits** — every merge commit on main gets a release. Gaps break the version chain.
- **Do not re-create existing tags** — if a tag already exists for a version number, skip it gracefully instead of erroring.
- **Do not use `--draft`** — releases are published immediately. Draft releases won't be picked up by deployment workflows.
