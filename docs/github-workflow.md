# GitHub Team Workflow with spec-kit

This guide explains how to use spec-kit's GitHub integration for team collaboration.

## Overview

spec-kit provides two commands for GitHub integration:

- **`/speckit.ghsync`** - Intelligently sync tasks to GitHub Issues with Epic/Sub-issue hierarchy (incremental updates)
- **`/speckit.pullrequest`** - Create Pull Requests with automatic issue closing

### Sub-Issues Feature

spec-kit uses GitHub's native sub-issues feature (via GraphQL API) to create a hierarchical relationship:
- **Epic Issue** - Parent issue tracking the entire feature
- **Sub-Issues** - Child issues for each Phase/User Story, linked to the Epic

This provides better organization in GitHub UI with automatic parent-child linking.

## Key Features

- **Epic titles**: `[001] Feature name` (with spec number prefix)
- **Sub-issue titles**: Clean titles without prefixes (no `[001]`, no "Phase 1:", no "US2:", no "(P2)")
- **Modern labels**: `epic`, `feature`, `bug`, `docs`, `refactor`, `test`, `enhancement` + priorities (`critical`, `high`, `medium`, `low`) + `spec-XXX`
- **Centralized mapping**: `.specify/memory/gh-issues-mapping.json` tracks all features
- **Incremental sync**: Re-running `/speckit.ghsync` only updates what changed
- **Flexible scopes**: Commit scopes derived from issue titles (`auth`, `api`, `db`, not `us1`, `us2`)

## Quick Start

```bash
# 1. Create feature spec and branch
/speckit.specify "Add multitenant cusdoor auth"

# 2. Create technical plan
/speckit.plan

# 3. Generate tasks
/speckit.tasks

# 4. Sync to GitHub Issues
/speckit.ghsync
# Creates Epic + sub-issues, updates centralized mapping

# 5. Team starts working
# Each developer assigns themselves to issues and works in the feature branch

# 6. Make commits and mark completed tasks
git commit -m "feat(auth): implement user authentication"
# Mark completed tasks in tasks.md, then sync
/speckit.ghsync

# 7. Create PR when done
/speckit.pullrequest
# Auto-closes all issues when merged
```

## Complete Workflow

### Phase 1: Planning (Project Lead)

```bash
# Create feature specification
/speckit.specify "Multitenant cusdoor auth with SSO"
# → Creates branch: 001-multitenant-cusdoor-auth
# → Creates: specs/001-multitenant-cusdoor-auth/spec.md

# Create implementation plan
/speckit.plan
# → Creates: specs/001-multitenant-cusdoor-auth/plan.md

# Generate task breakdown
/speckit.tasks
# → Creates: specs/001-multitenant-cusdoor-auth/tasks.md
#   - Phase 1: Setup (3 tasks)
#   - Phase 2: Core infrastructure (6 tasks)
#   - User authentication (8 tasks)
#   - Session management (4 tasks)
```

### Phase 2: GitHub Sync (Project Lead)

```bash
# Sync tasks to GitHub Issues
/speckit.ghsync

# Output:
# ✅ GitHub Issues synced successfully!
#
# Feature: [001] Multitenant cusdoor auth
#
# Epic Issue:
# #100 - [001] Multitenant cusdoor auth
#
# Sub-Issues:
# - #101 Setup (3 tasks) [`feature`, `medium`, `spec-001`]
# - #102 Core infrastructure (6 tasks) [`feature`, `high`, `spec-001`]
# - #103 User authentication (8 tasks) [`feature`, `critical`, `spec-001`]
# - #104 Session management (4 tasks) [`feature`, `high`, `spec-001`]
#
# Summary: 1 epic + 4 issues (21 tasks)
#
# Next steps:
# 1. Team members assign themselves to issues
# 2. Work in 001-multitenant-cusdoor-auth branch
# 3. Use conventional commits
```

### Phase 3: Team Development

#### Developer 1: Takes Phase 1 & 2

```bash
# 1. Assign in GitHub UI
# Go to issue #101, click "Assignees" → Assign yourself

# 2. Checkout feature branch
git checkout 003-chat-system
git pull origin 003-chat-system

# 3. Work on tasks
# ... edit files ...

# 4. Make commits
git commit -m "feat(setup): create project structure"

# 5. Push regularly
git push origin 003-chat-system

# 6. When sub-issue complete, mark tasks in tasks.md
vim specs/003-chat-system/tasks.md
# Mark [x] T001, T002, T003...

git commit -m "chore: complete setup phase"
git push

# 7. Sync to GitHub (closes completed sub-issues)
/speckit.ghsync

# 8. Move to next sub-issue
# Repeat for issue #102
```

#### Developer 2: Takes US1

```bash
# 1. Assign issue #103 to yourself in GitHub

# 2. Checkout feature branch
git checkout 003-chat-system
git pull origin 003-chat-system

# 3. Wait for Phase 2 to complete
# Issue #103 shows: "⚠️ Blocked by: #102 Phase 2"
# Check issue #102 status

# 4. Once Phase 2 done, start US1
# Work on T010, T011, T012...

# 5. Make commits
git commit -m "feat(auth): implement User model"
git commit -m "feat(auth): add authentication logic"
git commit -m "test(auth): add integration tests"

# 6. Pull regularly (other devs are pushing too)
git pull origin 003-chat-system

# 7. When sub-issue complete, mark all tasks in tasks.md
vim specs/003-chat-system/tasks.md
# Mark [x] T010, T011, T012...

git commit -m "chore: complete user authentication"
git push

# 8. Sync to GitHub (closes sub-issue #103)
/speckit.ghsync
```

#### Developer 3: Takes US2 (Parallel)

```bash
# 1. Assign issue #104 to yourself

# 2. Work in parallel with Developer 2
# US1 and US2 work on different files, no conflicts

git checkout 003-chat-system
git pull origin 003-chat-system

# 3. Make commits
git commit -m "feat(api): implement Message model"
git commit -m "feat(api): add message endpoints"

# 4. Pull regularly to get others' changes
git pull origin 003-chat-system

# 5. Mark tasks and sync when sub-issue done
vim specs/003-chat-system/tasks.md
git commit -m "chore: complete message API"
/speckit.ghsync
```

### Phase 4: Create Pull Request (Project Lead or Any Developer)

```bash
# When all issues are closed (or most work done):

/speckit.pullrequest

# Output:
# Checking branch status...
# ✓ Branch: 003-chat-system
# ✓ 32 commits ahead of main
# ✓ All changes pushed
#
# 📝 Pull Request Preview
# ═══════════════════════════════════════
# Title: feat: implement chat system (003)
# Base: main ← Head: 003-chat-system
#
# Body:
# Closes #100
#
# ## Summary
# Implementation of chat system with authentication,
# messaging, and real-time updates.
#
# ## Completed Work
# - ✅ #101 Phase 1: Setup
# - ✅ #102 Phase 2: Foundation
# - ✅ #103 US1: User Authentication (P1 🎯)
# - ✅ #104 US2: Message Sending (P1 🎯)
# - ✅ #105 US3: Real-time Updates (P2)
#
# Total: 5 issues, 29 tasks
#
# ## Closes
# Closes #100, #101, #102, #103, #104, #105
# ═══════════════════════════════════════
#
# Create this Pull Request? [Y/n]: y
#
# ✅ PR #42 created!
# https://github.com/owner/repo/pull/42
#
# Next steps:
# 1. Request reviews
# 2. Wait for CI checks
# 3. Merge (will auto-close all issues)
```

### Phase 5: Review and Merge

```bash
# 1. Team reviews PR in GitHub UI
# Add comments, request changes, approve

# 2. Address feedback
git checkout 003-chat-system
# ... make changes ...
git commit -m "fix(us1): address review feedback"
git push origin 003-chat-system
# PR updates automatically

# 3. Wait for approvals and CI checks

# 4. Merge PR (via GitHub UI)
# → Automatically closes: #100, #101, #102, #103, #104, #105
# → Feature complete! 🎉
```

## Issue Structure

### Epic Issue (#100)

```markdown
# 003-chat-system

**Feature Branch:** `003-chat-system`
**Spec:** `specs/003-chat-system/`

## Overview
Chat system with real-time messaging

## Work Breakdown

### Foundation (blocking)
- [ ] #101 Phase 1: Setup
- [ ] #102 Phase 2: Foundation

### User Stories
- [ ] #103 US1: User Authentication (P1 🎯 MVP)
- [ ] #104 US2: Message Sending (P1 🎯 MVP)
- [ ] #105 US3: Real-time Updates (P2)

## Progress
0/5 completed
```

### User Story Issue (#103)

```markdown
# US1: User Authentication

**Epic:** #100 | **Priority:** P1 MVP 🎯 | **Branch:** `003-chat-system`

## Goal
Implement user authentication with registration, login, session management

## Getting Started

```bash
git checkout 003-chat-system
git pull origin 003-chat-system

# Commits:
git commit -m "feat(auth): implement user authentication

Task: T012
Refs: #103"
```

## Tasks

**Tests**
- [ ] T010 Contract test for auth `tests/contract/test_auth.py`
- [ ] T011 Integration test `tests/integration/test_user_flow.py`

**Models**
- [ ] T012 Create User model `src/models/user.py`
- [ ] T013 Create Session model `src/models/session.py`

**Services**
- [ ] T014 Implement UserService `src/services/user_service.py`
- [ ] T015 Implement auth endpoints `src/api/auth.py`

**Progress:** 0/8 tasks

## Dependencies
⚠️ **Blocked by:** #102 Phase 2
🔄 **Parallel with:** #104, #105
```

## Commit Convention

### Format

```
<type>(<scope>): <summary>

<body>

Task: T012
Refs: #103
```

### Types

- **feat** - New feature
- **fix** - Bug fix
- **test** - Adding tests
- **refactor** - Code refactoring
- **docs** - Documentation
- **chore** - Maintenance

### Scopes

Use meaningful semantic scopes derived from the work area:
- **auth** - Authentication and authorization
- **api** - API endpoints and services
- **db** - Database models and migrations
- **setup** - Project setup and configuration
- Custom scopes as needed (avoid generic us1, us2, phase1 - use descriptive names)

### Examples

```bash
feat(auth): implement User model

Add User model with authentication fields.

Task: T012
Refs: #103
```

```bash
fix(api): resolve message ordering bug

Messages now display in chronological order.

Task: T019
Refs: #104
```

```bash
test(auth): add integration tests for auth flow

Task: T011
Refs: #103
```

## Best Practices

### For Project Leads

1. ✅ Create clear, detailed specs
2. ✅ Break work into logical User Stories
3. ✅ Run `/speckit.ghsync` after tasks are finalized
4. ✅ Assign issues based on team member strengths
5. ✅ Monitor progress via GitHub issue status
6. ✅ Create PR when all issues closed

### For Developers

1. ✅ Assign yourself to issues before starting
2. ✅ Pull frequently to stay in sync
3. ✅ Use conventional commits with task/issue refs
4. ✅ Check off tasks as you complete them
5. ✅ Close issues when all tasks done
6. ✅ Communicate blockers in issue comments

### For Teams

1. ✅ One feature branch per feature
2. ✅ Multiple developers work in same branch
3. ✅ Different User Stories = different files = no conflicts
4. ✅ Phase 1 & 2 must complete before User Stories
5. ✅ User Stories can be done in parallel (after Phase 2)
6. ✅ Regular communication in issue comments
7. ✅ One PR at the end closes all issues

## Coordination Tips

### Avoiding Conflicts

```bash
# Pull before starting work
git pull origin 003-chat-system

# Pull regularly during work
git pull origin 003-chat-system  # every hour or so

# Pull before committing
git pull origin 003-chat-system
git add -A
git commit -m "..."
git push origin 003-chat-system
```

### Handling Conflicts

```bash
# If git pull causes conflicts:
git pull origin 003-chat-system
# CONFLICT in src/config.py

# Resolve conflicts manually
# Edit src/config.py
# Remove <<<<<<, ======, >>>>>> markers

git add src/config.py
git commit -m "merge: resolve conflict in config"
git push origin 003-chat-system
```

### Communication

- 💬 Use issue comments for questions
- 🚫 Mention blockers immediately in issues
- 📢 Announce when you complete phases (Phase 1, Phase 2)
- 👥 Tag team members with @username
- 🔄 Update task checkboxes in real-time

## File Structure

```
specs/003-chat-system/
├── spec.md                    # Feature specification
├── plan.md                    # Technical plan
├── tasks.md                   # Task breakdown
├── data-model.md              # Data models
├── contracts/                 # API contracts
│   ├── auth.md
│   └── messages.md
├── research.md                # Technical research
└── quickstart.md              # Test scenarios

.specify/
└── memory/
    └── gh-issues-mapping.json # Centralized GitHub issue mapping (all features)
```

### gh-issues-mapping.json

Centralized mapping file for all features:

```json
{
  "repository": "owner/repo",
  "specifications": {
    "003": {
      "spec_number": "003",
      "spec_name": "chat-system",
      "spec_title": "Chat system",
      "spec_branch": "003-chat-system",
      "spec_dir": "specs/003-chat-system",
      "epic_issue": 100,
      "created_at": "2025-01-16T10:30:00Z",
      "updated_at": "2025-01-16T10:35:00Z",
      "issues": [
        {
          "number": 101,
          "title": "Setup",
          "type": "feature",
          "priority": "medium",
          "status": "open",
          "url": "https://github.com/owner/repo/issues/101",
          "created_at": "2025-01-16T10:31:00Z",
          "tasks": ["T001", "T002", "T003"]
        },
        {
          "number": 103,
          "title": "User Authentication",
          "type": "feature",
          "priority": "critical",
          "status": "open",
          "url": "https://github.com/owner/repo/issues/103",
          "created_at": "2025-01-16T10:32:00Z",
          "tasks": ["T010", "T011", "T012", "T013", "T014", "T015"]
        }
      ],
      "pull_request": {
        "number": 42,
        "url": "https://github.com/owner/repo/pull/42",
        "created_at": "2025-01-16T14:00:00Z",
        "status": "open"
      }
    }
  }
}
```

## Troubleshooting

### "No issue mapping found"

```bash
# Run ghsync first
/speckit.ghsync
```

### "Branch not pushed to remote"

```bash
git push -u origin 003-chat-system
```

### "Uncommitted changes"

```bash
git add -A
git commit -m "..."
# or
git stash
```

### "PR already exists"

```bash
# Update existing PR body:
/speckit.pullrequest  # Will ask if you want to update
```

### "Not authenticated with GitHub"

```bash
gh auth login
```

### "Permission denied"

```bash
# Ask repository admin for write access
# You need "Write" or "Admin" role
```

## FAQs

### Can I use this without GitHub?

Yes! The core spec-kit workflow works without GitHub. GitHub integration (`/speckit.ghsync`, `/speckit.pullrequest`) is optional for team coordination.

### Can multiple people work on the same User Story?

Yes, but it's better to assign one User Story per person to avoid conflicts. If needed, coordinate via issue comments.

### What if I need to create a sub-task?

GitHub task lists don't support sub-tasks. Break complex tasks into multiple T### tasks in tasks.md instead.

### Can I edit issue descriptions?

Yes! Edit issues in GitHub UI if tasks change. However, tasks.md is the source of truth - update it first.

### Do I need to create new issues for every feature?

Yes, run `/speckit.ghsync` for each new feature. Each feature gets its own Epic and issues.

### Can I work on multiple features simultaneously?

Yes, each feature has its own branch and issues. Switch branches as needed:
```bash
git checkout 003-chat-system    # Feature 1
git checkout 005-payment-system # Feature 2
```

## Summary

1. **Plan**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks`
2. **Sync**: `/speckit.ghsync` creates GitHub issues
3. **Work**: Team assigns issues, works in feature branch, makes commits
4. **Mark Done**: Update tasks.md with `[x]` for completed tasks, run `/speckit.ghsync` to close sub-issues
5. **PR**: `/speckit.pullrequest` creates PR with auto-closing
6. **Merge**: PR merge closes all issues automatically

🎉 **Result**: Organized, collaborative, traceable development!
