---
description: Create a Pull Request from feature branch to main with automatic issue closing
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --paths-only
  ps: scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

This command creates a Pull Request from the feature branch to main with proper formatting and automatic issue closing.

### Step 1: Prerequisites Check

1. Run `{SCRIPT}` to get feature paths
2. Verify we're in a git repository with GitHub remote:

```bash
# Check git repo
git rev-parse --git-dir 2>/dev/null || ERROR

# Get remote URL
remote_url=$(git config --get remote.origin.url)

# Verify it's GitHub
if [[ ! "$remote_url" =~ github.com ]]; then
  ERROR: Not a GitHub repository
fi
```

3. Get current branch:

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)
```

4. Verify current branch is a feature branch (matches pattern: ###-something):

```bash
if [[ ! "$current_branch" =~ ^[0-9]{3}- ]]; then
  WARNING: Current branch doesn't match feature pattern (###-name)
  Current: $current_branch
  Continue anyway? [y/N]
fi
```

### Step 2: Check Branch Status

Verify branch is ready for PR:

```bash
# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
  ERROR: You have uncommitted changes.

  Commit or stash changes first:
    git add -A && git commit -m "..."
    or
    git stash
fi

# Check if branch is pushed to remote
if ! git ls-remote --heads origin "$current_branch" | grep -q "$current_branch"; then
  WARNING: Branch not pushed to remote yet.

  Push now? [Y/n]: _

  # If yes:
  git push -u origin "$current_branch"
fi

# Check if branch is up to date with remote
local_hash=$(git rev-parse HEAD)
remote_hash=$(git rev-parse origin/"$current_branch")

if [[ "$local_hash" != "$remote_hash" ]]; then
  WARNING: Local branch differs from remote.

  Push local changes? [Y/n]: _

  # If yes:
  git push origin "$current_branch"
fi
```

### Step 3: Load Issue Mapping

1. Extract spec number from spec directory (e.g., `001` from `specs/001-multitenant-cusdoor-auth`)
2. Load `.specify/memory/gh-issues-mapping.json` if it exists
3. Find entry for current spec number in `.specifications["001"]`

```bash
mapping_file=".specify/memory/gh-issues-mapping.json"
spec_number="001"  # extracted from spec directory
spec_data=$(jq -r ".specifications[\"$spec_number\"]" "$mapping_file")
```

If exists and has entry for current spec:
- Load epic issue number: `.epic_issue`
- Load all sub-issue numbers: `.issues[].number`
- This will be used for automatic closing

If not exists or no entry for current spec:
- Warn user: "No issue mapping found for spec {NUMBER}. PR will not auto-close issues."
- Continue with PR creation (without Closes #...)

### Step 4: Analyze Commits

Get all commits in the spec branch (since diverging from main):

```bash
git log main..HEAD --oneline
```

From commits, extract:
1. **Issue references**: Lines with `Refs: #123` or `#123` in message
2. **Task IDs**: Lines with `Task: T012`
3. **Commit types**: Count feat, fix, test, refactor, docs, chore
4. **Scopes**: Extract (us1), (us2), (phase1), etc.

Build a summary:
```javascript
{
  total_commits: 15,
  types: {feat: 8, fix: 2, test: 3, refactor: 2},
  issues_referenced: [103, 104, 105],
  tasks_completed: ["T010", "T011", "T012", ...],
  scopes: ["us1", "us2", "phase1"]
}
```

### Step 5: Generate PR Title

**Format**: `[{SPEC_NUMBER}] {FEATURE_TITLE}`

Extract from branch name:
- Branch: `001-multitenant-cusdoor-auth` → Title: `[001] Multitenant cusdoor auth`
- Branch: `012-user-auth` → Title: `[012] User auth`

Process:
1. Extract spec number (e.g., `001`)
2. Extract feature name after number (e.g., `multitenant-cusdoor-auth`)
3. Convert kebab-case to readable format:
   - Replace dashes with spaces
   - Keep lowercase (e.g., `multitenant cusdoor auth`)

Note: Unlike issues, PR title doesn't need commit type prefix (feat/fix/etc.)

### Step 6: Generate PR Body

Build comprehensive PR body:

```markdown
Closes #[EPIC_ISSUE]

## Summary

[Auto-generate summary based on spec.md overview or feature name]

Implementation of [feature name] including:
- [List key components completed based on issue titles]

## Completed Work

[From issue mapping, list all issues with clean titles:]

- ✅ #101 [001] Setup (3 tasks) [feature, medium]
- ✅ #102 [001] Core infrastructure (6 tasks) [feature, high]
- ✅ #103 [001] User authentication (8 tasks) [feature, critical]
- ✅ #104 [001] Session management (4 tasks) [feature, high]

**Total**: [X] issues, [Y] tasks completed

## Changes Summary

[Based on commit analysis:]

- **[8] Features** implemented
- **[2] Fixes** applied
- **[3] Tests** added
- **[2] Refactorings** completed

## Key Files Changed

[Extract from git diff --stat main..HEAD, show top 10 files:]

```
src/models/user.py          | 125 +++++++++++
src/services/auth.py        |  89 ++++++++
src/api/endpoints.py        | 156 +++++++++++++
tests/test_auth.py          | 234 +++++++++++++++++++
...
```

## Test Results

- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] No breaking changes

## Closes

Closes #[EPIC], #101, #102, #103, #104

---

🤖 Generated with [spec-kit](https://github.com/anthropics/spec-kit)
```

### Step 7: Preview PR

Show the user what will be created:

```
📝 Pull Request Preview
═══════════════════════════════════════════════════════════════

Title: [001] Multitenant cusdoor auth

Base: main ← Head: 001-multitenant-cusdoor-auth

Body:
───────────────────────────────────────────────────────────────
Closes #100

## Summary
Implementation of multitenant cusdoor auth including user authentication,
session management, and core infrastructure.

## Completed Work

- ✅ #101 [001] Setup (3 tasks) [feature, medium]
- ✅ #102 [001] Core infrastructure (6 tasks) [feature, high]
- ✅ #103 [001] User authentication (8 tasks) [feature, critical]
- ✅ #104 [001] Session management (4 tasks) [feature, high]

**Total**: 4 issues, 21 tasks completed

## Changes Summary
- 8 Features implemented
- 2 Fixes applied
- 3 Tests added

## Closes
Closes #100, #101, #102, #103, #104

🤖 Generated with spec-kit
───────────────────────────────────────────────────────────────

Create this Pull Request? [Y/n]: _
```

### Step 8: Create PR

If user confirms:

```bash
gh pr create \
  --base main \
  --head "$current_branch" \
  --title "[GENERATED_TITLE]" \
  --body "$(cat <<'EOF'
[GENERATED_BODY]
EOF
)"
```

Capture PR URL from output.

### Step 9: Update Issue Mapping

Update `.specify/memory/gh-issues-mapping.json` with PR information for the current spec:

```json
{
  "repository": "owner/repo",
  "features": {
    "001": {
      "spec_number": "001",
      "feature_name": "multitenant-cusdoor-auth",
      "epic_issue": 100,
      "pull_request": {
        "number": 42,
        "url": "https://github.com/owner/repo/pull/42",
        "created_at": "2025-01-16T11:00:00Z",
        "status": "open"
      },
      "issues": [...]
    }
  }
}
```

### Step 10: Success Output

```
✅ Pull Request created successfully!

PR #42: [001] Multitenant cusdoor auth
https://github.com/owner/repo/pull/42

📊 Summary:
- Base branch: main
- Feature branch: 001-multitenant-cusdoor-auth
- Commits: 15
- Issues closed: 5 (when merged)
- Epic: #100

🔗 Quick links:
- View PR: https://github.com/owner/repo/pull/42
- View Epic: https://github.com/owner/repo/issues/100
- View all issues: https://github.com/owner/repo/issues?q=label:spec-001

📝 Next steps:
1. Request reviews from team members
2. Address review feedback if needed
3. Wait for CI/CD checks to pass
4. Merge when ready (will auto-close all issues)

ℹ️  After merge, issues #100, #101, #102, #103, #104 will close automatically.
```

## Advanced Features

### Custom PR Description

If user provides arguments, use as additional context:

```
$ /speckit.pullrequest "This PR adds the chat system with real-time features"

[Include user's text in Summary section]
```

### Draft PR

Check if user wants to create a draft PR:

```
Create as draft PR? [y/N]: _
```

If yes, add `--draft` flag:
```bash
gh pr create --draft ...
```

### Reviewers

If `.github/CODEOWNERS` exists or if user wants to add reviewers:

```
Add reviewers? [y/N]: _

Reviewers (comma-separated GitHub usernames): developer1,developer2

# Add to gh command:
gh pr create --reviewer developer1,developer2 ...
```

### Labels

Automatically add labels from Epic to PR:

```bash
# Get labels from Epic issue
labels=$(gh issue view $epic_issue --json labels -q '.labels[].name' | tr '\n' ',')

# Add to PR
gh pr edit $pr_number --add-label "$labels"
```

## Error Handling

1. **Not on a feature branch**:
   ```
   ERROR: Not on a feature branch.
   Current branch: main

   Checkout a feature branch first:
     git checkout 003-chat-system
   ```

2. **Uncommitted changes**:
   ```
   ERROR: You have uncommitted changes.

   Files modified:
     src/models/user.py
     src/api/auth.py

   Commit changes first:
     git add -A
     git commit -m "..."
   ```

3. **Branch not pushed**:
   ```
   ERROR: Branch not pushed to remote.

   Push branch first:
     git push -u origin 003-chat-system
   ```

4. **PR already exists**:
   ```
   ERROR: A Pull Request already exists for this branch.

   Existing PR: #42
   https://github.com/owner/repo/pull/42

   Update existing PR? [y/N]: _

   # If yes, update PR body with new content
   ```

5. **No commits since main**:
   ```
   ERROR: No commits found since diverging from main.

   Make commits first before creating PR.
   ```

6. **`gh` not authenticated**:
   ```
   ERROR: Not authenticated with GitHub.

   Authenticate first:
     gh auth login
   ```

## Examples

### Example 1: Simple PR Creation

```
$ /speckit.pullrequest

Checking branch status...
✓ Branch: 001-multitenant-cusdoor-auth
✓ 15 commits ahead of main
✓ Branch pushed to remote
✓ No uncommitted changes

Loading issue mapping...
✓ Found mapping for spec 001
✓ 4 issues to close

Analyzing commits...
✓ 15 commits analyzed
✓ 8 features, 2 fixes, 3 tests

📝 Pull Request Preview
═══════════════════════════════════════
Title: [001] Multitenant cusdoor auth
Base: main ← Head: 001-multitenant-cusdoor-auth
...

Create this Pull Request? [Y/n]: y

✅ PR #42 created!
https://github.com/owner/repo/pull/42
```

### Example 2: Draft PR

```
$ /speckit.pullrequest

...

Create as draft PR? [y/N]: y

✅ Draft PR #42 created!

Mark as ready for review when ready:
  gh pr ready 42
```

### Example 3: No Issue Mapping

```
$ /speckit.pullrequest

⚠️  No issue mapping found for spec 001.
PR will not automatically close issues.

Run /speckit.ghsync first to create GitHub issues.

Continue without issue closing? [y/N]: y

...

✅ PR #42 created!
Note: This PR will not auto-close any issues.
```

## Notes

- PR is created from current branch to `main` (default base branch)
- PR title format: `[{SPEC_NUMBER}] {FEATURE_TITLE}` (no "feat:" prefix)
- All issues from mapping are included in "Closes" section
- PR body includes comprehensive summary with clean issue titles
- Issue mapping (`.specify/memory/gh-issues-mapping.json`) is updated with PR information
- When PR is merged, all listed issues close automatically via "Closes #..." syntax
- If PR already exists, command offers to update it
- Draft PRs can be created for work-in-progress
- Issue lookup is by spec number, not by directory path
