#!/usr/bin/env bash
set -e

# ==============================================================================
# Continuous GitHub Synchronization & Project Tracking Automation Script
# ==============================================================================
# This script automates branch staging, commit formatting, main branch merging,
# and remote repository synchronization for the OpenLane RV64I Processor project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="$WORKSPACE_DIR/bin:/var/home/linuxbrew/.linuxbrew/bin:$PATH"
export HOMEBREW_GIT_PATH=/usr/bin/git
cd "$WORKSPACE_DIR"

echo "=========================================================="
echo "Starting Continuous GitHub Synchronization Flow"
echo "=========================================================="

# 1. Check current branch and status
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "--> Active Branch: $CURRENT_BRANCH"
git status -s

# 2. Optionally run verification before syncing if --verify flag is passed
if [ "$1" == "--verify" ]; then
    echo "--> Executing pre-sync quality verification (lint & sim-all)..."
    make lint
    python3 verif/scripts/test_driver.py
    echo "--> Quality verification passed cleanly!"
fi

# 3. Check if there are uncommitted changes to stage
if [ -n "$(git status --porcelain)" ]; then
    echo "--> Staging all modified and new project files..."
    git add -A
    
    # Use provided commit message or default to conventional commit format
    COMMIT_MSG="$2"
    if [ -z "$COMMIT_MSG" ]; then
        COMMIT_MSG="ci(sync): automated continuous project tracking and repository sync [$(date +'%Y-%m-%d %H:%M:%S')]"
    fi
    
    echo "--> Committing changes with message: \"$COMMIT_MSG\""
    git commit -m "$COMMIT_MSG"
else
    echo "--> Working directory clean. No local modifications to commit."
fi

# 4. Push active feature branch if not on main
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "--> Pushing active branch '$CURRENT_BRANCH' to remote origin..."
    git push -u origin "$CURRENT_BRANCH"
    
    echo "--> Switching to 'main' branch and merging '$CURRENT_BRANCH'..."
    git checkout main
    git merge "$CURRENT_BRANCH" --no-edit
fi

# 5. Push main branch and all repository tags to origin
echo "--> Pushing 'main' branch and all tags to remote origin (github.com/krutideepanpanda)..."
git push --all origin
git push --tags origin

# 6. Return to initial working branch if applicable
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "--> Returning to working branch '$CURRENT_BRANCH'..."
    git checkout "$CURRENT_BRANCH"
fi

echo "=========================================================="
echo "🎉 Continuous GitHub Synchronization Completed Successfully!"
echo "=========================================================="
