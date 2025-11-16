# GitHub Issue Template for spec-kit

This template is NOT used directly by users. It's referenced by automation scripts.

## Epic Issue Format

**Title:** `[001] Multitenant cusdoor auth`
**Labels:** `epic`, `spec-001`

**Body:**

```markdown
**Spec:** `specs/001-multitenant-cusdoor-auth/`
**Branch:** `001-multitenant-cusdoor-auth`

## Overview

Feature implementation for {feature_title}.

## Sub-Issues

{sub_issues_list}

## Progress

**Status:** {completed}/{total} completed

---

## Instructions

### For Team Members

1. **Assign yourself** to issues you'll work on
2. **Checkout feature branch:**
   ```bash
   git checkout {feature_branch}
   git pull origin {feature_branch}
   ```

1. **Make commits** with conventional format:

   ```bash
   git commit -m "type(scope): description

   Task: T012
   Refs: #{issue_number}"
   ```

1. **Check off tasks** in issues as you complete them

1. **Close issues** when all tasks are done

---

**When all sub-issues are closed:**
Create PR: `{feature_branch} → main` to complete this epic.
```text

---

## Sub-Issue Format

**Title:** `Setup` (clean title, no prefixes, no [001], no "Phase 1:", no "US2:", no "(P2)")
**Labels:** `feature`, `medium`, `spec-001`

**Body:**

```markdown
**Epic:** #{epic_number} | **Branch:** `{feature_branch}`

## Goal

{goal_description}

## Getting Started

```bash
# Start working
git checkout {feature_branch}
git pull origin {feature_branch}

# Make commits
git commit -m "type(scope): description

Task: T012
Refs: #{issue_number}"
```text

## Tasks

{task_list}

**Progress:** 0/{task_count} tasks

---

## Commit Convention

Use conventional commit format:

```text
type(scope): description

[optional body]

Task: T012
Refs: #{issue_number}
```text

**Types:** feat, fix, test, refactor, docs, chore
**Scope:** Optional (auth, api, db, setup, etc.)

**Examples:**

```bash
feat(auth): implement User model
fix(api): resolve message ordering
test(auth): add integration tests

```

---

**When complete:**
- ✅ Check all tasks above
- ✅ Close this issue
- ✅ Update Epic #{epic_number}
```text

---

## Notes

- Epic title: `[XXX] Feature name` (with spec number prefix)
- Sub-issue title: `Feature name` (clean, no prefixes)
- Labels for all issues: type (`epic`/`feature`/`bug`/`docs`/`refactor`/`test`/`enhancement`) + priority (`critical`/`high`/`medium`/`low`) + `spec-XXX`
- Epic body MUST contain list of sub-issues with checkboxes
