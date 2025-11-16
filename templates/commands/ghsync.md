---
description: Sync tasks.md to GitHub Issues using automated script
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

This command reads tasks.md and generates a JSON payload to sync with GitHub Issues via `gh-issues-sync.sh` script.

## ⚠️ CRITICAL INSTRUCTIONS

**DO NOT:**
- ❌ Write Python scripts to parse tasks.md
- ❌ Write JavaScript/Node.js scripts
- ❌ Create any intermediate parsing scripts
- ❌ Use complex regex parsing tools

**DO:**
- ✅ Read tasks.md using the Read tool
- ✅ Understand the markdown structure natively (you're an LLM!)
- ✅ Directly construct the JSON payload from what you read
- ✅ Use simple bash commands to pipe JSON to script

You are Claude - you can understand markdown structure directly. No parsing scripts needed!

### Step 1: Get Specification Directory

1. Run `{SCRIPT}` to get specification paths
2. Extract absolute path to SPEC_DIR (e.g., `/path/to/specs/001-spec-name`)
3. Extract SPEC_NUMBER (e.g., `001` from `001-spec-name`)
4. Extract SPEC_NAME (e.g., `multitenant-cusdoor-auth`)
5. Calculate SPEC_TITLE by converting dashes to spaces (e.g., `multitenant cusdoor auth`)
6. Calculate SPEC_BRANCH as `{SPEC_NUMBER}-{SPEC_NAME}`

### Step 2: Read and Understand tasks.md

Simply read `$SPEC_DIR/tasks.md` using the Read tool. You understand markdown structure natively - no parsing script needed.

**For each `## ` heading:**
1. Extract the **clean title** by removing:
   - `Phase 1:`, `Phase 2:`, etc.
   - `User Story 1 -`, `User Story 2:`, `User Story 3`, etc.
   - Priority markers: `(P1)`, `(P2)`, `(P3)`
   - Prefix markers: `US1:`, `US2:`, `P1:`, `P2:`
   - Leading/trailing whitespace

2. Determine **type**: always `feature` (unless you detect specific markers like "bug", "test", "docs" in title)

3. Determine **priority** from markers in original line:
   - `(P1)` → `critical`
   - `(P2)` → `high`
   - `(P3)` → `medium`
   - No marker → `low`

4. Extract **goal**: First non-empty paragraph after heading (starts with letter)

5. Extract **tasks**: All lines matching `- [ ] T### Description` or `- [x] T### Description`

**Example input:**
```markdown
## Phase 1: Setup (P3)

Setup project infrastructure and dependencies.

- [ ] T001 Create project structure
- [ ] T002 Setup dependencies
- [ ] T003 Configure environment

## User Story 1 - User Authentication (P1)

Implement user login and registration.

- [ ] T020 User model
- [ ] T021 Login endpoint
```

**Parsed output (conceptual):**
```json
[
  {
    "title": "Setup",
    "type": "feature",
    "priority": "medium",
    "goal": "Setup project infrastructure and dependencies.",
    "tasks": [
      "- [ ] T001 Create project structure",
      "- [ ] T002 Setup dependencies",
      "- [ ] T003 Configure environment"
    ]
  },
  {
    "title": "User Authentication",
    "type": "feature",
    "priority": "critical",
    "goal": "Implement user login and registration.",
    "tasks": [
      "- [ ] T020 User model",
      "- [ ] T021 Login endpoint"
    ]
  }
]
```

### Step 3: Generate JSON Payload

Directly construct the JSON payload based on what you read from tasks.md. Do NOT write code - just build the JSON structure:

```json
{
  "spec_number": "001",
  "spec_name": "multitenant-cusdoor-auth",
  "spec_title": "Multitenant cusdoor auth",
  "spec_branch": "001-multitenant-cusdoor-auth",
  "spec_dir": "specs/001-multitenant-cusdoor-auth",
  "epic_title": "[001] Multitenant cusdoor auth",
  "issues": [
    {
      "title": "Setup",
      "type": "feature",
      "priority": "medium",
      "goal": "Setup project infrastructure and dependencies.",
      "tasks": [
        "- [ ] T001 Create project structure",
        "- [ ] T002 Setup dependencies",
        "- [ ] T003 Configure environment"
      ]
    },
    {
      "title": "User Authentication",
      "type": "feature",
      "priority": "critical",
      "goal": "Implement user login and registration.",
      "tasks": [
        "- [ ] T020 User model",
        "- [ ] T021 Login endpoint"
      ]
    }
  ]
}
```

**Important:**
- Epic title: `[{SPEC_NUMBER}] {SPEC_TITLE}` (with brackets and spec number)
- Sub-issue titles: Clean names WITHOUT `[001]`, WITHOUT "Phase 1:", WITHOUT "User Story 3"
- All issues get labels: `type` + `priority` + `spec-{SPEC_NUMBER}` (added by script)

### Step 4: Call gh-issues-sync.sh Script

Pipe the JSON payload directly to the script using bash command:

```bash
# Find the script location
if [[ -f "scripts/bash/gh-issues-sync.sh" ]]; then
    SCRIPT_PATH="scripts/bash/gh-issues-sync.sh"
elif [[ -f ".specify/scripts/gh-issues-sync.sh" ]]; then
    SCRIPT_PATH=".specify/scripts/gh-issues-sync.sh"
else
    echo "ERROR: gh-issues-sync.sh not found"
    exit 1
fi

# Pass JSON via stdin
echo 'YOUR_JSON_PAYLOAD_HERE' | bash "$SCRIPT_PATH" --json-stdin
```

**Important:** Replace `YOUR_JSON_PAYLOAD_HERE` with the actual JSON string you constructed in Step 3. Use proper JSON escaping for bash.

### Step 5: Display Success Message

The script will output progress to stderr. Display a user-friendly summary:

```
✅ GitHub Issues synced successfully!

Specification: [001] Multitenant cusdoor auth

Epic Issue: #{epic_number} - [001] Multitenant cusdoor auth

Sub-issues created:
- #{issue1} - Setup [`feature`, `medium`, `spec-001`]
- #{issue2} - User Authentication [`feature`, `critical`, `spec-001`]

Repository: owner/repo

View all issues: https://github.com/owner/repo/issues?q=label:spec-001

The mapping file .specify/memory/gh-issues-mapping.json has been updated.
```

## Important Notes

1. **DO NOT** include "Phase 1:", "User Story 3", "(P2)", etc. in issue titles
2. **DO** preserve the actual feature/task names after removing prefixes
3. Epic title includes `[001]` prefix, sub-issue titles do NOT
4. Script handles:
   - GitHub API calls
   - Label creation
   - Mapping file updates
   - Idempotent operations (won't duplicate issues)

## Error Handling

If script fails:
- Display error message from stderr
- Show path to script location
- Suggest checking prerequisites: `gh auth status`, `jq --version`

## Example Full Flow

Here's what your execution should look like:

### Step-by-Step Example

```bash
# 1. Get spec info
Run check-prerequisites.sh
→ SPEC_DIR="specs/001-demo-feature"
→ SPEC_NUMBER="001"
→ SPEC_NAME="demo-feature"

# 2. Read tasks.md
Use Read tool on specs/001-demo-feature/tasks.md

# 3. Construct JSON directly (in your response)
You see the content:
  ## Phase 1: Setup (P2)

  Setup infrastructure

  - [ ] T001 Create structure
  - [ ] T002 Add configs

You construct:
{
  "spec_number": "001",
  "spec_name": "demo-feature",
  "spec_title": "demo feature",
  "spec_branch": "001-demo-feature",
  "spec_dir": "specs/001-demo-feature",
  "epic_title": "[001] demo feature",
  "issues": [
    {
      "title": "Setup",
      "type": "feature",
      "priority": "high",
      "goal": "Setup infrastructure",
      "tasks": ["- [ ] T001 Create structure", "- [ ] T002 Add configs"]
    }
  ]
}

# 4. Run script with JSON
cat << 'EOF' | bash scripts/bash/gh-issues-sync.sh --json-stdin
{
  "spec_number": "001",
  ...
}
EOF
```

### What NOT to do

❌ **BAD:**
```bash
# Don't write parsing scripts!
cat <<'EOF' | python3
import json
import re
# ... 50 lines of parsing code ...
EOF
```

✅ **GOOD:**
```bash
# Just construct the JSON and pipe it
cat << 'EOF' | bash scripts/bash/gh-issues-sync.sh --json-stdin
{ "spec_number": "001", "issues": [...] }
EOF
```
