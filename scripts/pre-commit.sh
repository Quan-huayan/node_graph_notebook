#!/bin/bash
# Pre-commit hook for Node Graph Notebook
# This script runs before each commit to ensure code quality

set -e

echo "🔍 Running pre-commit checks..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Format code
echo "📝 Formatting code..."
if dart format --set-exit-if-changed .; then
    echo -e "${GREEN}✓ Code formatted${NC}"
else
    echo -e "${RED}✗ Code formatting failed${NC}"
    echo "Please run 'dart format .' to fix formatting issues"
    exit 1
fi

# Analyze code
echo "🔎 Analyzing code..."
if dart analyze --fatal-infos --fatal-warnings; then
    echo -e "${GREEN}✓ Code analysis passed${NC}"
else
    echo -e "${RED}✗ Code analysis failed${NC}"
    echo "Please fix the issues above before committing"
    exit 1
fi

# Check if model files changed, if so run build_runner
MODEL_CHANGED=$(git diff --cached --name-only | grep -E "^lib/core/models/.*\.dart$" || true)
if [ -n "$MODEL_CHANGED" ]; then
    echo "🔨 Model files changed, running build_runner..."
    if flutter pub run build_runner build --delete-conflicting-outputs; then
        echo -e "${GREEN}✓ Build runner completed${NC}"
    else
        echo -e "${RED}✗ Build runner failed${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
