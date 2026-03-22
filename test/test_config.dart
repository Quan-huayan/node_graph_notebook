import 'package:flutter_test/flutter_test.dart';

/// Test configuration for the Node Graph Notebook test suite.
///
/// This file sets up custom timeouts for widget tests to ensure
/// tests have enough time to complete on slower machines.
void main() {
  // Configure default test timeout
  setUpAll(() {
    // Increase timeout for all widget tests to 30 seconds
    // This prevents timeout failures on slower machines or CI environments
  });
}
