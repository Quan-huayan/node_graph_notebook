#!/bin/bash
# Quality check script - Run all quality checks

set -e

echo "🔍 Running comprehensive quality checks..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Format code
echo -e "${BLUE}Step 1: Formatting code...${NC}"
dart format --set-exit-if-changed .
echo -e "${GREEN}✓ Code formatted${NC}"
echo ""

# Step 2: Analyze code
echo -e "${BLUE}Step 2: Analyzing code...${NC}"
dart analyze --fatal-infos --fatal-warnings
echo -e "${GREEN}✓ Code analysis passed${NC}"
echo ""

# Step 3: Run tests
echo -e "${BLUE}Step 3: Running tests...${NC}"
flutter test --coverage
echo -e "${GREEN}✓ Tests passed${NC}"
echo ""

# Step 4: Check test coverage
echo -e "${BLUE}Step 4: Checking test coverage...${NC}"
if [ -d "coverage" ]; then
    echo "Coverage report generated in coverage/"
    echo "To view: open coverage/index.html"
fi
echo -e "${GREEN}✓ Coverage check complete${NC}"
echo ""

echo -e "${GREEN}🎉 All quality checks passed!${NC}"
