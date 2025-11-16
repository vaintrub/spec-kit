# GitHub Integration Commands

Quick reference for spec-kit's GitHub integration commands.

## Commands Overview

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/speckit.ghsync` | Create GitHub Issues from tasks.md | After running `/speckit.tasks` |
| `/speckit.pullrequest` | Create Pull Request | When feature is ready to merge |

## `/speckit.ghsync`

**Purpose**: Sync tasks.md to GitHub Issues for team coordination using native sub-issues hierarchy.

**Creates**:

- 1 Epic issue with `[001]` prefix (entire feature) as parent
- N sub-issues with clean titles linked to Epic via GitHub's native sub-issue feature (no prefixes, no "Phase 1:", no "US2:", no "(P2)")
- Native parent-child relationship using GraphQL API
- Task lists inside each issue
- Labels: `epic`, `feature`, `bug`, `docs`, `refactor`, `test`, `enhancement` + priorities (`critical`, `high`, `medium`, `low`) + `spec-XXX`
- `.specify/memory/gh-issues-mapping.json` for centralized tracking

**Usage**:

```bash
/speckit.ghsync
```

**Output**:

```text
✅ GitHub Issues synced successfully!

Feature: [001] Multitenant cusdoor auth

Epic Issue:
#100 - [001] Multitenant cusdoor auth

Sub-Issues:
- #101 Setup (3 tasks) [`feature`, `medium`, `spec-001`]
- #102 Core infrastructure (6 tasks) [`feature`, `high`, `spec-001`]
- #103 User authentication (8 tasks) [`feature`, `critical`, `spec-001`]
- #104 Session management (4 tasks) [`feature`, `high`, `spec-001`]
```

**Requirements**:

- Git repository with GitHub remote
- `gh` CLI installed and authenticated
- tasks.md exists

**Labels Created**:

- **Types:** `epic`, `feature`, `bug`, `docs`, `refactor`, `test`, `enhancement`
- **Priorities:** `critical`, `high`, `medium`, `low`
- **Spec labels:** `spec-001`, `spec-002`, etc. (auto-generated per spec)

---

## `/speckit.pullrequest`

**Purpose**: Create Pull Request with automatic issue closing.

**Usage**:

```bash
/speckit.pullrequest
```

With custom description:

```bash
/speckit.pullrequest "This adds the chat system with real-time features"
```

**What it does**:

1. Checks branch status (pushed, up-to-date)
2. Analyzes commits in the branch
3. Loads issue mapping
4. Generates PR title and body
5. Lists all issues to close
6. Creates PR via `gh pr create`

**Generated PR**:

Title:

```text
[001] Multitenant cusdoor auth
```

Body:

```markdown
Closes #100

## Summary
Implementation of multitenant cusdoor auth...

## Completed Work
- ✅ #101 [001] Setup (3 tasks) [feature, medium]
- ✅ #102 [001] Core infrastructure (6 tasks) [feature, high]
- ✅ #103 [001] User authentication (8 tasks) [feature, critical]
- ✅ #104 [001] Session management (4 tasks) [feature, high]

## Closes
Closes #100, #101, #102, #103, #104
```

**Result**: When PR merges, all issues close automatically.

---

## Workflow Example

```bash
# 1. Planning
/speckit.specify "Add multitenant cusdoor auth"
/speckit.plan
/speckit.tasks

# 2. Sync to GitHub
/speckit.ghsync
# → Creates issues #100-#104

# 3. Team Development
# Developer 1 works on Setup
git checkout 001-multitenant-cusdoor-auth
# ... make changes ...
git commit -m "feat(setup): create project structure"
git push origin 001-multitenant-cusdoor-auth

# When sub-issue complete, mark tasks in tasks.md and sync
vim specs/001-feature/tasks.md  # Mark [x] for completed tasks
git commit -m "chore: complete setup tasks"
/speckit.ghsync  # Sync to GitHub, closes completed sub-issues

# 4. Create PR
/speckit.pullrequest
# → Creates PR #42 that closes #100-#104

# 5. Merge
# Merge PR in GitHub UI → all issues close automatically
```

---

## File Structure

```text
.specify/
└── memory/
    └── gh-issues-mapping.json    # Centralized mapping for all features

specs/001-multitenant-cusdoor-auth/
├── spec.md
├── plan.md
└── tasks.md
```

### gh-issues-mapping.json

Centralized file tracking all features:

```json
{
  "repository": "owner/repo",
  "specifications": {
    "001": {
      "spec_number": "001",
      "spec_name": "multitenant-cusdoor-auth",
      "spec_title": "Multitenant cusdoor auth",
      "spec_branch": "001-multitenant-cusdoor-auth",
      "spec_dir": "specs/001-multitenant-cusdoor-auth",
      "epic_issue": 100,
      "created_at": "2025-01-16T10:30:00Z",
      "updated_at": "2025-01-16T10:35:00Z",
      "issues": [
        {
          "number": 103,
          "title": "User authentication",
          "type": "feature",
          "priority": "critical",
          "status": "open",
          "url": "https://github.com/owner/repo/issues/103",
          "created_at": "2025-01-16T10:31:00Z",
          "tasks": ["T010", "T011", "T012"]
        }
      ]
    }
  }
}
```

---

## Prerequisites

### Install GitHub CLI

**macOS**:

```bash
brew install gh
```

**Linux**:

```bash
# Debian/Ubuntu
sudo apt install gh

# Fedora/CentOS
sudo dnf install gh
```

**Windows**:

```bash
winget install GitHub.cli
```

### Authenticate

```bash
gh auth login
```

Follow prompts to authenticate with GitHub.

### Verify

```bash
gh auth status
```

---

## Tips

### For Project Leads

- Run `/speckit.ghsync` after finalizing tasks.md
- Assign issues to team members in GitHub UI
- Monitor progress via issue status
- Run `/speckit.pullrequest` when all issues closed

### For Developers

- Assign yourself to issues before starting
- Make regular commits with clear messages
- Pull frequently: `git pull origin <branch>`
- Mark completed tasks in tasks.md
- Run `/speckit.ghsync` to sync status to GitHub

### For Teams

- One feature branch per feature
- Multiple developers work in same branch
- Different User Stories = different files = minimal conflicts
- Pull regularly to stay in sync
- Communicate via issue comments

---

## Troubleshooting

### `gh` not found

```bash
# Install GitHub CLI
brew install gh  # macOS
```

### Not authenticated

```bash
gh auth login
```

### Not a GitHub repository

```bash
# Add GitHub remote
git remote add origin https://github.com/owner/repo.git
```

### No permission to create issues

- Ask repository admin for "Write" access
- Or fork the repository

### Issue mapping not found

```bash
# Run ghsync first
/speckit.ghsync
```

### PR already exists

- Command will ask if you want to update existing PR
- Or close old PR and create new one

---

## Advanced Usage

### Custom Labels

Edit label colors/descriptions after creation:
```bash
gh label edit "us-1" --color "FF0000" --description "User Story 1: Auth"
```

### Draft PRs

When prompted by `/speckit.pullrequest`, answer yes to "Create as draft?"
```bash
gh pr ready <number>  # Mark as ready later
```

### Add Reviewers

After creating PR:
```bash
gh pr edit <number> --add-reviewer username1,username2
```

### Update Issue Descriptions

Edit issues directly in GitHub UI if tasks change. Remember to update tasks.md as the source of truth.

---

## See Also

- [Full GitHub Workflow Guide](./github-workflow.md) - Complete team workflow
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit format specification
- [GitHub CLI Docs](https://cli.github.com/) - gh command reference
