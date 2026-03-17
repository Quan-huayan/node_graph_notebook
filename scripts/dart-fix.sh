#!/bin/bash
# Dart Fix Script for Linux/Mac - Auto-fixes applicable lint issues

echo "========================================"
echo "Dart Auto-Fix Script"
echo "========================================"
echo ""

# Check if dart is available
if ! command -v dart &> /dev/null; then
    echo "Error: Dart is not installed or not in PATH"
    echo "Please install Dart SDK first"
    exit 1
fi

echo "Running dart fix --apply..."
dart fix --apply

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Fix Summary"
    echo "========================================"
    echo ""
    echo "Successfully applied automatic fixes!"
    echo ""
    echo "The following types of issues were automatically fixed:"
    echo "  - Style issues (prefer_single_quotes, prefer_const_constructors, etc.)"
    echo "  - Unnecessary code (unnecessary_const, unnecessary_new, etc.)"
    echo "  - Modern Dart patterns (prefer_spread_collections, prefer_if_elements, etc.)"
    echo "  - Type simplifications (prefer_typing_uninitialized_variables, etc.)"
    echo ""
    echo "Manual fixes may still be needed for:"
    echo "  - Documentation (public_member_api_docs)"
    echo "  - Performance issues (avoid_slow_async_io)"
    echo "  - Security concerns (control_flow_in_finally)"
    echo "  - Logic issues (avoid_print, etc.)"
    echo ""
    echo "Run 'flutter analyze' to see remaining issues"
    echo ""
else
    echo ""
    echo "Error: dart fix failed"
    echo ""
    exit 1
fi

exit 0
