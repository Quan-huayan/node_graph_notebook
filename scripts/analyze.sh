#!/bin/bash
# Clean analyze script that filters out third-party plugin warnings

echo "Running Flutter analyze..."
echo ""

# Run flutter analyze and filter out known third-party warnings
flutter analyze 2>&1 | grep -v "Package file_picker:" | grep -v "Ask the maintainers of file_picker" | grep -v "default_package: file_picker"

# Get exit code
ANALYZE_RESULT=${PIPESTATUS[0]}

echo ""
if [ $ANALYZE_RESULT -eq 0 ]; then
  echo "✅ No issues found in your code!"
else
  echo "⚠️  Issues found. Please review the output above."
fi

exit $ANALYZE_RESULT
