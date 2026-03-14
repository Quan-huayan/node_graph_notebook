// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that is provided in flutter_test. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/app.dart';
import 'package:node_graph_notebook/core/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 初始化SharedPreferences mock
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test - loads without crashing', (WidgetTester tester) async {
    // 初始化服务
    final settingsService = SettingsService();
    await settingsService.init();
    final themeService = ThemeService();
    await themeService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(NodeGraphNotebookApp(
      settingsService: settingsService,
      themeService: themeService,
    ));

    // Verify that the app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
