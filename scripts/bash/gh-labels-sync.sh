#!/usr/bin/env bash
#
# gh-labels-sync.sh
# Synchronizes GitHub labels for spec-kit
#
# Usage:
#   gh-labels-sync.sh [spec_number]
#
# Examples:
#   gh-labels-sync.sh           # Sync base labels only
#   gh-labels-sync.sh 001       # Sync base labels + spec-001
#
# Exit codes:
#   0 - Success
#   1 - GitHub CLI not found or not authenticated
#   2 - Invalid arguments

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Create label (silently fails if exists)
create_label() {
    local name=$1
    local color=$2
    local description=$3

    if gh label create "$name" --color "$color" --description "$description" 2>/dev/null; then
        success "Created label: $name"
    else
        # Label already exists, that's OK
        :
    fi
}

# Check prerequisites
check_prerequisites() {
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) not found"
        error "Install from: https://cli.github.com/"
        return 1
    fi

    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub"
        error "Run: gh auth login"
        return 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        error "Not in a git repository"
        return 1
    fi

    return 0
}

# Sync all base labels
sync_base_labels() {
    info "Syncing base labels..."

    # Type labels
    create_label "epic" "8B00FF" "Epic issue for entire feature"
    create_label "feature" "0366D6" "New feature implementation"
    create_label "bug" "D73A4A" "Bug fix"
    create_label "docs" "0075CA" "Documentation"
    create_label "refactor" "FBCA04" "Code refactoring"
    create_label "test" "0E8A16" "Testing"
    create_label "enhancement" "A2EEEF" "Enhancement to existing feature"

    # Priority labels
    create_label "critical" "B60205" "Critical priority - must be done"
    create_label "high" "D93F0B" "High priority - important"
    create_label "medium" "FBCA04" "Medium priority - normal"
    create_label "low" "0E8A16" "Low priority - nice to have"

    success "Base labels synced"
}

# Sync spec-specific label
sync_spec_label() {
    local spec_number=$1

    info "Syncing spec label: spec-$spec_number"

    create_label "spec-$spec_number" "D4C5F9" "Related to spec $spec_number"

    success "Spec label synced: spec-$spec_number"
}

# Main function
main() {
    local spec_number="${1:-}"

    # Validate spec number format if provided
    if [[ -n "$spec_number" ]] && [[ ! "$spec_number" =~ ^[0-9]{3}$ ]]; then
        error "Invalid spec number format: $spec_number"
        error "Expected format: 3 digits (e.g., 001, 042, 123)"
        return 2
    fi

    # Check prerequisites
    check_prerequisites || return 1

    # Sync base labels
    sync_base_labels

    # Sync spec label if provided
    if [[ -n "$spec_number" ]]; then
        sync_spec_label "$spec_number"
    fi

    echo
    success "All labels synced successfully!"

    return 0
}

# Run main function
main "$@"
