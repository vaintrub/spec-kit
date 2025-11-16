#!/usr/bin/env bash
#
# gh-issues-sync.sh
# Automatic GitHub Issues synchronization with spec-kit tasks
#
# Features:
#   - Creates GitHub issues from JSON input using GraphQL API
#   - Creates Epic issue as parent with sub-issues hierarchy
#   - Sub-issues are linked to Epic via GitHub's native sub-issue feature
#   - Automatically closes issues when all T-tasks are completed
#   - Updates mapping after each action (ensures consistency)
#   - Works without user prompts
#
# Usage:
#   gh-issues-sync.sh --json <json_file>
#   echo "$json" | gh-issues-sync.sh --json-stdin
#
# JSON Format:
#   {
#     "spec_number": "001",
#     "spec_name": "multitenant-cusdoor-auth",
#     "spec_title": "Multitenant cusdoor auth",
#     "spec_branch": "001-multitenant-cusdoor-auth",
#     "spec_dir": "specs/001-multitenant-cusdoor-auth",
#     "epic_title": "[001] Multitenant cusdoor auth",
#     "issues": [
#       {
#         "title": "Setup",
#         "type": "feature",
#         "priority": "medium",
#         "goal": "Setup project infrastructure",
#         "tasks": [
#           "- [ ] T001 Create project structure",
#           "- [ ] T002 Setup dependencies"
#         ]
#       }
#     ]
#   }
#
# Environment:
#   Requires: gh CLI, jq
#   Writes: .specify/memory/gh-issues-mapping.json

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Print functions
info() { echo -e "${BLUE}ℹ${NC} $*" >&2; }
success() { echo -e "${GREEN}✓${NC} $*" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $*" >&2; }
error() { echo -e "${RED}✗${NC} $*" >&2; }
section() { echo -e "\n${CYAN}▸${NC} $*\n" >&2; }

# Global variables
INPUT_JSON=""
SPEC_NUMBER=""
SPEC_NAME=""
SPEC_TITLE=""
SPEC_BRANCH=""
SPEC_DIR=""
EPIC_TITLE=""
MAPPING_FILE=".specify/memory/gh-issues-mapping.json"
REPO_URL=""
REPO_OWNER=""
REPO_NAME=""
REPO_ID=""
EPIC_ISSUE_ID=""

# ============================================================================
# Helper Functions
# ============================================================================

check_prerequisites() {
    local missing=()

    if ! command -v gh &> /dev/null; then
        missing+=("gh - GitHub CLI")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq - JSON processor")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools:"
        for tool in "${missing[@]}"; do
            error "  - $tool"
        done
        return 1
    fi

    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub"
        error "Run: gh auth login"
        return 1
    fi

    return 0
}

parse_input_json() {
    # Validate JSON format first
    if ! echo "$INPUT_JSON" | jq empty 2>/dev/null; then
        error "Invalid JSON format in input"
        return 1
    fi

    # Extract fields from JSON
    SPEC_NUMBER=$(echo "$INPUT_JSON" | jq -r '.spec_number')
    SPEC_NAME=$(echo "$INPUT_JSON" | jq -r '.spec_name')
    SPEC_TITLE=$(echo "$INPUT_JSON" | jq -r '.spec_title')
    SPEC_BRANCH=$(echo "$INPUT_JSON" | jq -r '.spec_branch')
    SPEC_DIR=$(echo "$INPUT_JSON" | jq -r '.spec_dir')
    EPIC_TITLE=$(echo "$INPUT_JSON" | jq -r '.epic_title')

    if [[ -z "$SPEC_NUMBER" || "$SPEC_NUMBER" == "null" ]]; then
        error "Invalid JSON: missing spec_number"
        return 1
    fi

    info "Spec: $SPEC_NUMBER ($SPEC_TITLE)" >&2
    return 0
}

get_repo_info() {
    local repo_info=$(gh repo view --json nameWithOwner,owner,name 2>/dev/null || echo "")

    if [[ -z "$repo_info" ]]; then
        error "Cannot determine GitHub repository"
        error "Are you in a GitHub repository?"
        return 1
    fi

    local name_with_owner=$(echo "$repo_info" | jq -r '.nameWithOwner')
    REPO_URL="https://github.com/${name_with_owner}"
    REPO_OWNER=$(echo "$repo_info" | jq -r '.owner.login')
    REPO_NAME=$(echo "$repo_info" | jq -r '.name')

    # Get Repository ID using GraphQL (required for sub-issues)
    REPO_ID=$(gh api graphql -f query='
query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    id
  }
}' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" --jq '.data.repository.id' 2>/dev/null || echo "")

    if [[ -z "$REPO_ID" ]]; then
        error "Failed to get Repository ID via GraphQL"
        return 1
    fi

    info "Repository: $REPO_URL (ID: $REPO_ID)"
    return 0
}

load_mapping() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        mkdir -p "$(dirname "$MAPPING_FILE")"
        echo '{"repository":"'"$REPO_URL"'","specifications":{}}' > "$MAPPING_FILE"
        info "Created new mapping file"
    fi

    return 0
}

get_spec_data() {
    local spec=$1
    jq -r ".specifications[\"$spec\"] // {}" "$MAPPING_FILE"
}

save_spec_data() {
    local spec=$1
    local data=$2

    # Validate input
    if [[ -z "$data" || "$data" == "null" || "$data" == "{}" ]]; then
        error "Invalid data passed to save_spec_data (empty or null)"
        return 1
    fi

    # Validate JSON format
    if ! echo "$data" | jq empty 2>/dev/null; then
        error "Invalid JSON data passed to save_spec_data"
        echo "Data: $data" >&2
        return 1
    fi

    local tmp=$(mktemp)
    local jq_error=$(mktemp)

    jq --argjson data "$data" \
       --arg spec "$spec" \
       --arg repo "$REPO_URL" \
       '.specifications[$spec] = $data | .repository = $repo' \
       "$MAPPING_FILE" > "$tmp" 2>"$jq_error"

    if [[ $? -ne 0 ]]; then
        error "jq failed to update mapping:"
        cat "$jq_error" >&2
        rm -f "$tmp" "$jq_error"
        return 1
    fi

    if [[ ! -s "$tmp" ]]; then
        error "Output file is empty after jq processing"
        rm -f "$tmp" "$jq_error"
        return 1
    fi

    mv "$tmp" "$MAPPING_FILE"
    rm -f "$jq_error"
    success "Updated mapping for spec $spec"
    return 0
}

# ============================================================================
# Issue Template Rendering
# ============================================================================

render_epic_body() {
    local spec_summary=""
    local plan_summary=""

    # Try to read spec.md summary (first 10 non-empty lines after ## Summary or first user story)
    if [[ -f "$SPEC_DIR/spec.md" ]]; then
        spec_summary=$(sed -n '/^## Summary/,/^##/p' "$SPEC_DIR/spec.md" | head -n 10 | grep -v "^##" | grep -v "^$" | head -5)
        if [[ -z "$spec_summary" ]]; then
            # Try User Scenarios section
            spec_summary=$(sed -n '/^### User Story 1/,/^---/p' "$SPEC_DIR/spec.md" | head -n 8 | grep -v "^###" | grep -v "^---")
        fi
    fi

    # Try to read plan.md summary
    if [[ -f "$SPEC_DIR/plan.md" ]]; then
        plan_summary=$(sed -n '/^## Summary/,/^##/p' "$SPEC_DIR/plan.md" | head -n 10 | grep -v "^##" | grep -v "^$" | head -5)
    fi

    # Build GitHub blob URLs for spec files
    local spec_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/spec.md"
    local plan_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/plan.md"
    local tasks_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/tasks.md"

    cat <<EOF
# $SPEC_TITLE

**Branch:** \`$SPEC_BRANCH\` | **Spec:** [\`spec.md\`]($spec_url) | **Plan:** [\`plan.md\`]($plan_url) | **Tasks:** [\`tasks.md\`]($tasks_url)

## Overview

$spec_summary

## Implementation Plan

$plan_summary

---

<details>
<summary><b>📋 Instructions for Team Members</b></summary>

### Getting Started

1. **Assign yourself** to sub-issues you'll work on
2. **Checkout spec branch:**
   \`\`\`bash
   git checkout $SPEC_BRANCH
   git pull origin $SPEC_BRANCH
   \`\`\`

3. **Work on tasks** from sub-issues

### Commit Convention

Make commits with conventional format:

\`\`\`bash
git commit -m "type(scope): description

Task: T012
Refs: #<issue-number>"
\`\`\`

**Types:** feat, fix, test, refactor, docs, chore
**Scope:** Optional (auth, api, db, setup, etc.)

### Completion

1. Check off tasks in sub-issues as you complete them
2. Close sub-issues when all tasks are done
3. When all sub-issues are closed, create PR: \`$SPEC_BRANCH → main\`

</details>

---

📖 **Documentation**: See [\`spec.md\`]($spec_url) for detailed requirements and [\`plan.md\`]($plan_url) for implementation approach.
EOF
}

render_task_body() {
    local epic_number=$1
    local goal=$2
    local tasks=$3
    local title=$4
    local type=$5

    # Build GitHub blob URLs for spec files
    local spec_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/spec.md"
    local plan_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/plan.md"
    local tasks_url="${REPO_URL}/blob/${SPEC_BRANCH}/${SPEC_DIR}/tasks.md"

    # Try to extract expanded goal from plan.md or research.md
    local expanded_goal=""
    if [[ -f "$SPEC_DIR/plan.md" ]]; then
        # Look for a section that mentions this title or related content
        expanded_goal=$(grep -A 5 -i "$title" "$SPEC_DIR/plan.md" 2>/dev/null | head -5 | grep -v "^#" || echo "")
    fi

    # Try to find User Story from spec.md if it's a feature
    local user_story=""
    if [[ "$type" == "feature" && -f "$SPEC_DIR/spec.md" ]]; then
        # Try to find matching user story by title
        user_story=$(sed -n "/### User Story.*${title}/,/^---/p" "$SPEC_DIR/spec.md" 2>/dev/null | head -10)
    fi

    # Build acceptance criteria section
    local acceptance_section=""
    if [[ -n "$user_story" ]]; then
        # Extract acceptance scenarios from user story
        local scenarios=$(echo "$user_story" | sed -n '/\*\*Acceptance Scenarios\*\*/,/^$/p' | tail -n +2)
        if [[ -n "$scenarios" ]]; then
            acceptance_section="## Acceptance Criteria

$scenarios"
        fi
    fi

    # Build bug-specific sections if type is bug
    local bug_sections=""
    if [[ "$type" == "bug" ]]; then
        bug_sections="
## Reproduction Steps

1. [Step 1]
2. [Step 2]
3. [Expected vs Actual behavior]

## Impact

- **Severity**: [High/Medium/Low]
- **Users Affected**: [Describe]
- **Workaround**: [If available]
"
    fi

    cat <<EOF
**Epic:** [#$epic_number]($REPO_URL/issues/$epic_number) | **Branch:** \`$SPEC_BRANCH\` | **Docs:** [\`spec.md\`]($spec_url) · [\`plan.md\`]($plan_url) · [\`tasks.md\`]($tasks_url)

## Goal

$goal

$expanded_goal

$bug_sections

$acceptance_section

## Tasks

$tasks
EOF
}

# ============================================================================
# Task Status Management
# ============================================================================

check_all_tasks_done() {
    local feature_dir=$1
    local tasks_array=$2
    local tasks_file="$feature_dir/tasks.md"

    if [[ ! -f "$tasks_file" ]]; then
        warn "tasks.md not found: $tasks_file"
        return 1
    fi

    # Parse tasks array (newline-separated string)
    while IFS= read -r task_line; do
        if [[ "$task_line" =~ (T[0-9]{3}) ]]; then
            local task_id="${BASH_REMATCH[1]}"
            # Check if task is marked as done in tasks.md
            # Use -e to avoid option parsing issues
            if ! grep -q -e "- \[x\] ${task_id}" "$tasks_file" && ! grep -q -e "- \[X\] ${task_id}" "$tasks_file"; then
                return 1  # Not all done
            fi
        fi
    done <<< "$tasks_array"

    return 0  # All done
}

get_tasks_with_status() {
    local feature_dir=$1
    local tasks_array=$2
    local tasks_file="$feature_dir/tasks.md"
    local result=""

    if [[ ! -f "$tasks_file" ]]; then
        echo "$tasks_array"
        return
    fi

    # Update task status based on tasks.md
    while IFS= read -r task_line; do
        if [[ "$task_line" =~ (T[0-9]{3}) ]]; then
            local task_id="${BASH_REMATCH[1]}"
            # Check if task is marked as done
            # Use -e to avoid option parsing issues
            if grep -q -e "- \[x\] ${task_id}" "$tasks_file" || grep -q -e "- \[X\] ${task_id}" "$tasks_file"; then
                # Replace [ ] with [x]
                task_line=$(echo "$task_line" | sed 's/- \[ \]/- [x]/')
            else
                # Ensure it's [ ] not [x]
                task_line=$(echo "$task_line" | sed 's/- \[x\]/- [ ]/' | sed 's/- \[X\]/- [ ]/')
            fi
        fi
        if [[ -n "$result" ]]; then
            result+=$'\n'
        fi
        result+="$task_line"
    done <<< "$tasks_array"

    echo "$result"
}

sync_github_status() {
    local issue_number=$1

    info "Checking GitHub status for issue #$issue_number..."

    # Get current status from GitHub
    local gh_status=$(gh issue view "$issue_number" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")

    if [[ "$gh_status" == "CLOSED" ]]; then
        echo "closed"
    elif [[ "$gh_status" == "OPEN" ]]; then
        echo "open"
    else
        echo "unknown"
    fi
}

# ============================================================================
# GitHub Operations
# ============================================================================

ensure_labels() {
    info "Ensuring GitHub labels exist..."

    # Find gh-labels-sync.sh in common locations
    local label_script=""

    if [[ -f ".specify/scripts/bash/gh-labels-sync.sh" ]]; then
        label_script=".specify/scripts/bash/gh-labels-sync.sh"
    elif [[ -f "scripts/bash/gh-labels-sync.sh" ]]; then
        label_script="scripts/bash/gh-labels-sync.sh"
    elif [[ -f ".specify/scripts/gh-labels-sync.sh" ]]; then
        label_script=".specify/scripts/gh-labels-sync.sh"
    fi

    if [[ -n "$label_script" ]]; then
        bash "$label_script" "$SPEC_NUMBER" >&2 || {
            warn "Failed to sync labels, continuing anyway"
        }
    else
        warn "gh-labels-sync.sh not found, skipping label sync"
    fi

    return 0
}

create_epic_issue() {
    # Creates a new Epic issue via GraphQL API
    # Note: This function only creates NEW Epics. Existing Epic lookup is handled
    # by sync_issues() using the mapping file as source of truth.

    info "Creating Epic issue via GraphQL: $EPIC_TITLE"

    # Create Epic with spec/plan summary
    local epic_body=$(render_epic_body)

    # Use GraphQL to create Epic issue
    local response=$(gh api graphql -f query='
mutation($repositoryId: ID!, $title: String!, $body: String!) {
  createIssue(input: {
    repositoryId: $repositoryId
    title: $title
    body: $body
  }) {
    issue {
      id
      number
      url
    }
  }
}' -f repositoryId="$REPO_ID" \
   -f title="$EPIC_TITLE" \
   -f body="$epic_body" 2>&1)

    # Check for GraphQL errors first
    local gql_errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -n "$gql_errors" ]]; then
        error "GraphQL error creating Epic issue"
        error "Errors: $gql_errors"
        return 1
    fi

    local issue_number=$(echo "$response" | jq -r '.data.createIssue.issue.number' 2>/dev/null || echo "")
    local issue_id=$(echo "$response" | jq -r '.data.createIssue.issue.id' 2>/dev/null || echo "")

    if [[ -z "$issue_number" || "$issue_number" == "null" ]]; then
        error "Failed to create Epic issue via GraphQL"
        error "Response: $response"
        return 1
    fi

    if [[ -z "$issue_id" || "$issue_id" == "null" ]]; then
        error "Failed to extract Epic GraphQL ID"
        error "Response: $response"
        return 1
    fi

    # Add labels to Epic using REST API (GraphQL doesn't support labels in createIssue)
    gh issue edit "$issue_number" --add-label "epic,spec-$SPEC_NUMBER" >&2 || {
        warn "Failed to add labels to Epic #$issue_number"
    }

    success "Created Epic: #$issue_number (ID: $issue_id)"

    # Return both issue_number and issue_id (space-separated)
    echo "$issue_number $issue_id"
}

create_sub_issue() {
    local epic_number=$1
    local title=$2
    local type=$3
    local priority=$4
    local goal=$5
    local tasks=$6

    # Only spec-XXX label on sub-issues (type/priority only on Epic)
    local labels="spec-$SPEC_NUMBER"

    info "Creating sub-issue via GraphQL: $title"

    local body=$(render_task_body "$epic_number" "$goal" "$tasks" "$title" "$type")

    # Use GraphQL to create sub-issue with parentIssueId
    local response=$(gh api graphql -f query='
mutation($repositoryId: ID!, $title: String!, $body: String!, $parentIssueId: ID!) {
  createIssue(input: {
    repositoryId: $repositoryId
    title: $title
    body: $body
    parentIssueId: $parentIssueId
  }) {
    issue {
      id
      number
      url
    }
  }
}' -f repositoryId="$REPO_ID" \
   -f title="$title" \
   -f body="$body" \
   -f parentIssueId="$EPIC_ISSUE_ID" 2>&1)

    # Check for GraphQL errors first
    local gql_errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -n "$gql_errors" ]]; then
        error "GraphQL error creating sub-issue: $title"
        error "Errors: $gql_errors"
        return 1
    fi

    local issue_number=$(echo "$response" | jq -r '.data.createIssue.issue.number' 2>/dev/null || echo "")

    if [[ -z "$issue_number" || "$issue_number" == "null" ]]; then
        error "Failed to create sub-issue via GraphQL: $title"
        error "Response: $response"
        return 1
    fi

    # Add labels using REST API (GraphQL doesn't support labels in createIssue)
    gh issue edit "$issue_number" --add-label "$labels" >&2 || {
        warn "Failed to add labels to sub-issue #$issue_number"
    }

    success "Created sub-issue: #$issue_number"
    echo "$issue_number"
}

update_sub_issue() {
    local issue_number=$1
    local epic_number=$2
    local goal=$3
    local tasks=$4
    local title=$5
    local type=$6

    info "Updating sub-issue #$issue_number..."

    local body=$(render_task_body "$epic_number" "$goal" "$tasks" "$title" "$type")

    gh issue edit "$issue_number" --body "$body" >&2 || {
        warn "Failed to update issue #$issue_number"
        return 1
    }

    success "Updated sub-issue #$issue_number"
}

close_issue() {
    local issue_number=$1

    info "Closing issue #$issue_number (all tasks completed)..."

    gh issue close "$issue_number" \
        --comment "✅ All tasks completed. Closing automatically (synced from tasks.md)." \
        >&2 && success "Closed issue #$issue_number"
}

reopen_issue() {
    local issue_number=$1

    info "Reopening issue #$issue_number (tasks.md shows incomplete tasks)..."

    gh issue reopen "$issue_number" \
        --comment "🔄 Reopening: tasks.md shows incomplete tasks." \
        >&2 && success "Reopened issue #$issue_number"
}

sync_issue() {
    local issue_number=$1
    local epic_number=$2
    local title=$3
    local type=$4
    local priority=$5
    local goal=$6
    local tasks=$7

    # Get updated tasks with current status from tasks.md
    local updated_tasks=$(get_tasks_with_status "$SPEC_DIR" "$tasks")

    # Check if all tasks are done
    local all_done=false
    if check_all_tasks_done "$SPEC_DIR" "$tasks"; then
        all_done=true
    fi

    # Get current GitHub status
    local gh_status=$(sync_github_status "$issue_number")

    # Determine action based on tasks.md status and GitHub status
    if [[ "$all_done" == true ]]; then
        # All tasks done in tasks.md
        if [[ "$gh_status" == "open" ]]; then
            # Close issue in GitHub
            update_sub_issue "$issue_number" "$epic_number" "$goal" "$updated_tasks" "$title" "$type"
            close_issue "$issue_number"
            echo "closed"  # Return new status
        else
            # Already closed, just update body if needed
            update_sub_issue "$issue_number" "$epic_number" "$goal" "$updated_tasks" "$title" "$type"
            echo "closed"
        fi
    else
        # Not all tasks done in tasks.md
        if [[ "$gh_status" == "closed" ]]; then
            # Reopen issue (tasks.md = source of truth)
            reopen_issue "$issue_number"
            update_sub_issue "$issue_number" "$epic_number" "$goal" "$updated_tasks" "$title" "$type"
            echo "open"  # Return new status
        else
            # Already open, just update body with current status
            update_sub_issue "$issue_number" "$epic_number" "$goal" "$updated_tasks" "$title" "$type"
            echo "open"
        fi
    fi
}

update_epic_labels() {
    local epic_number=$1

    info "Updating Epic #$epic_number labels..."

    # Get all sub-issues from mapping
    local spec_data=$(get_spec_data "$SPEC_NUMBER")
    local issues_json=$(echo "$spec_data" | jq -r '.issues // []')

    # Collect unique types and priorities
    local types=$(echo "$issues_json" | jq -r '.[].type' | sort -u)
    local priorities=$(echo "$issues_json" | jq -r '.[].priority' | sort -u)

    # Determine highest priority (critical > high > medium > low)
    local epic_priority="low"
    if echo "$priorities" | grep -q "critical"; then
        epic_priority="critical"
    elif echo "$priorities" | grep -q "high"; then
        epic_priority="high"
    elif echo "$priorities" | grep -q "medium"; then
        epic_priority="medium"
    fi

    # Determine primary type (feature if any, otherwise first type)
    local epic_type=$(echo "$types" | grep "feature" | head -1)
    if [[ -z "$epic_type" ]]; then
        epic_type=$(echo "$types" | head -1)
    fi

    # Build label list: epic, type, priority, spec-XXX
    local epic_labels="epic"
    if [[ -n "$epic_type" ]]; then
        epic_labels="$epic_labels,$epic_type"
    fi
    if [[ -n "$epic_priority" ]]; then
        epic_labels="$epic_labels,$epic_priority"
    fi
    epic_labels="$epic_labels,spec-$SPEC_NUMBER"

    # Update Epic labels
    gh issue edit "$epic_number" --add-label "$epic_labels" >&2 || {
        warn "Failed to update Epic labels"
    }

    success "Updated Epic #$epic_number labels: $epic_labels"
}

update_epic_with_sub_issues() {
    local epic_number=$1

    info "Updating Epic #$epic_number body..."

    # Render Epic body with spec/plan summary
    local epic_body=$(render_epic_body)

    gh issue edit "$epic_number" --body "$epic_body" >&2 || {
        warn "Failed to update Epic body"
    }

    success "Updated Epic #$epic_number body with spec/plan summary"
}

# ============================================================================
# Main Sync Logic
# ============================================================================

sync_issues() {
    section "Syncing GitHub Issues"

    # Check if spec branch exists on remote
    info "Checking if branch $SPEC_BRANCH is pushed to remote..."

    if ! git ls-remote --exit-code --heads origin "$SPEC_BRANCH" >/dev/null 2>&1; then
        error "Branch '$SPEC_BRANCH' is not pushed to remote repository"
        error ""
        error "Please push the branch first:"
        error "  git push -u origin $SPEC_BRANCH"
        error ""
        error "This is required because GitHub issue links reference files in the remote branch."
        return 1
    fi

    success "Branch $SPEC_BRANCH found on remote"

    # Get issues array from JSON
    local issues_json=$(echo "$INPUT_JSON" | jq -r '.issues // []')
    local issue_count=$(echo "$issues_json" | jq 'length')

    if [[ "$issue_count" -eq 0 ]]; then
        warn "No issues found in input JSON"
        return 1
    fi

    info "Found $issue_count issues to sync"

    local spec_data=$(get_spec_data "$SPEC_NUMBER")
    local epic_number=""

    # Check if Epic already exists in mapping (mapping is the source of truth)
    # We rely on mapping file rather than searching GitHub by title to avoid issues
    # with duplicate/closed issues
    if [[ "$spec_data" != "{}" ]]; then
        epic_number=$(echo "$spec_data" | jq -r '.epic_issue // empty')

        if [[ -n "$epic_number" ]]; then
            # Try to get GraphQL ID from mapping first
            local epic_gql_id=$(echo "$spec_data" | jq -r '.epic_issue_id // empty')

            # If not in mapping, fetch from GitHub
            if [[ -z "$epic_gql_id" ]]; then
                info "Epic GraphQL ID not in mapping, fetching from GitHub..."
                epic_gql_id=$(gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
    }
  }
}' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" -F number="$epic_number" --jq '.data.repository.issue.id' 2>/dev/null || echo "")
            fi

            if [[ -n "$epic_gql_id" ]]; then
                info "Found existing Epic in mapping: #$epic_number (ID: $epic_gql_id)"
                EPIC_ISSUE_ID="$epic_gql_id"
            else
                warn "Epic #$epic_number from mapping not found in GitHub, will create new one"
                epic_number=""
                EPIC_ISSUE_ID=""
            fi
        fi
    fi

    # Create Epic if doesn't exist
    if [[ -z "$epic_number" ]]; then
        # Function returns "number id" space-separated
        local epic_result=$(create_epic_issue)
        epic_number=$(echo "$epic_result" | awk '{print $1}')
        EPIC_ISSUE_ID=$(echo "$epic_result" | awk '{print $2}')

        # Verify both values were extracted
        if [[ -z "$epic_number" || -z "$EPIC_ISSUE_ID" ]]; then
            error "Failed to extract Epic number or ID from function result"
            error "Result was: '$epic_result'"
            return 1
        fi

        info "Epic created: #$epic_number (ID: $EPIC_ISSUE_ID)"

        # Save Epic to mapping immediately (including GraphQL ID)
        spec_data=$(jq -n \
            --arg spec "$SPEC_NUMBER" \
            --arg name "$SPEC_NAME" \
            --arg title "$SPEC_TITLE" \
            --arg branch "$SPEC_BRANCH" \
            --arg dir "$SPEC_DIR" \
            --arg epic "$epic_number" \
            --arg epic_id "$EPIC_ISSUE_ID" \
            --arg repo "$REPO_URL" \
            '{
                spec_number: $spec,
                spec_name: $name,
                spec_title: $title,
                spec_branch: $branch,
                spec_dir: $dir,
                epic_issue: ($epic | tonumber),
                epic_issue_id: $epic_id,
                repository: $repo,
                created_at: (now | todate),
                updated_at: (now | todate),
                issues: []
            }')

        if ! save_spec_data "$SPEC_NUMBER" "$spec_data"; then
            error "Failed to save Epic to mapping, aborting"
            return 1
        fi
    fi

    # Verify EPIC_ISSUE_ID is set before creating sub-issues
    if [[ -z "$EPIC_ISSUE_ID" ]]; then
        error "EPIC_ISSUE_ID is empty - cannot create sub-issues"
        error "Epic number: $epic_number"
        return 1
    fi

    info "Using Epic #$epic_number with GraphQL ID: $EPIC_ISSUE_ID"

    # Get existing issues from mapping
    local existing_issues=$(echo "$spec_data" | jq -r '.issues // []')

    # Sync sub-issues
    while IFS= read -r issue_info; do
        local title=$(echo "$issue_info" | jq -r '.title')
        local type=$(echo "$issue_info" | jq -r '.type')
        local priority=$(echo "$issue_info" | jq -r '.priority')
        local goal=$(echo "$issue_info" | jq -r '.goal')
        local tasks=$(echo "$issue_info" | jq -r '.tasks | join("\n")')

        # Check if issue already exists (use --arg for safe string interpolation)
        local existing_num=$(echo "$existing_issues" | jq --arg t "$title" -r '.[] | select(.title == $t) | .number' 2>/dev/null || echo "")

        if [[ -n "$existing_num" ]]; then
            # Issue exists - sync it
            info "Syncing existing issue: #$existing_num ($title)"
            local new_status=$(sync_issue "$existing_num" "$epic_number" "$title" "$type" "$priority" "$goal" "$tasks")

            # Update mapping with new status
            spec_data=$(jq --arg num "$existing_num" \
                           --arg status "$new_status" \
                           '(.issues[] | select(.number == ($num | tonumber)) | .status) = $status | .updated_at = (now | todate)' \
                           <<< "$spec_data")

            if ! save_spec_data "$SPEC_NUMBER" "$spec_data"; then
                error "Failed to update mapping after syncing issue #$existing_num"
                return 1
            fi
        else
            # Create new sub-issue
            local issue_num=$(create_sub_issue "$epic_number" "$title" "$type" "$priority" "$goal" "$tasks")

            # Update mapping immediately after creating issue
            # Extract task IDs from tasks string
            local task_ids=$(echo "$tasks" | grep -oE 'T[0-9]{3}' | jq -R . | jq -s .)

            local issue_obj=$(jq -n \
                --arg num "$issue_num" \
                --arg title "$title" \
                --arg type "$type" \
                --arg priority "$priority" \
                --arg url "https://github.com/$REPO_URL/issues/$issue_num" \
                --argjson tasks "$task_ids" \
                '{
                    number: ($num | tonumber),
                    title: $title,
                    type: $type,
                    priority: $priority,
                    status: "open",
                    url: $url,
                    created_at: (now | todate),
                    tasks: $tasks
                }')

            spec_data=$(jq --argjson issue "$issue_obj" \
                '.issues += [$issue] | .updated_at = (now | todate)' <<< "$spec_data")

            if ! save_spec_data "$SPEC_NUMBER" "$spec_data"; then
                error "Failed to save mapping after creating issue #$issue_num"
                return 1
            fi
        fi
    done < <(echo "$issues_json" | jq -c '.[]')

    # Update Epic with all sub-issues
    update_epic_with_sub_issues "$epic_number"

    # Update Epic labels with aggregated type/priority from sub-issues
    update_epic_labels "$epic_number"

    # Check if all sub-issues are closed -> close Epic
    spec_data=$(get_spec_data "$SPEC_NUMBER")
    local issues_json=$(echo "$spec_data" | jq -r '.issues // []')
    local total_issues=$(echo "$issues_json" | jq 'length')

    # Only check Epic status if there are actually issues
    if [[ "$total_issues" -gt 0 ]]; then
        local all_closed=true
        local closed_count=0

        while IFS= read -r issue_info; do
            local issue_status=$(echo "$issue_info" | jq -r '.status')
            if [[ "$issue_status" == "closed" ]]; then
                closed_count=$((closed_count + 1))
            else
                all_closed=false
            fi
        done < <(echo "$issues_json" | jq -c '.[]')

        info "Epic status: $closed_count/$total_issues sub-issues closed"

        local epic_gh_status=$(sync_github_status "$epic_number")

        if [[ "$all_closed" == true ]]; then
            if [[ "$epic_gh_status" == "open" ]]; then
                info "All sub-issues closed, closing Epic #$epic_number..."
                gh issue close "$epic_number" \
                    --comment "✅ All sub-issues completed. Closing Epic automatically." \
                    >&2 && success "Closed Epic #$epic_number"
            else
                info "Epic #$epic_number already closed (all sub-issues done)"
            fi
        else
            if [[ "$epic_gh_status" == "closed" ]]; then
                info "Reopening Epic #$epic_number (sub-issues still in progress)..."
                gh issue reopen "$epic_number" \
                    --comment "🔄 Reopening Epic: sub-issues still in progress." \
                    >&2 && success "Reopened Epic #$epic_number"
            else
                info "Epic #$epic_number remains open ($closed_count/$total_issues sub-issues closed)"
            fi
        fi
    else
        warn "No sub-issues found in mapping, Epic #$epic_number remains open"
    fi

    success "Sync completed"
    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    local json_file=""
    local use_stdin=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                json_file="$2"
                shift 2
                ;;
            --json-stdin)
                use_stdin=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                error "Usage: $0 --json <file> | --json-stdin"
                return 1
                ;;
        esac
    done

    # Read JSON
    if [[ "$use_stdin" == true ]]; then
        INPUT_JSON=$(cat)
    elif [[ -n "$json_file" ]]; then
        if [[ ! -f "$json_file" ]]; then
            error "JSON file not found: $json_file"
            return 1
        fi
        INPUT_JSON=$(cat "$json_file")
    else
        error "Must specify --json <file> or --json-stdin"
        return 1
    fi

    section "GitHub Issues Sync"

    check_prerequisites || return 1
    parse_input_json || return 1
    get_repo_info || return 1
    load_mapping || return 1
    ensure_labels || return 1
    sync_issues || return 1

    echo >&2
    success "All done!"
    echo >&2
    info "View issues: https://github.com/$REPO_URL/issues?q=label:spec-$SPEC_NUMBER"

    return 0
}

main "$@"
