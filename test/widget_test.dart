// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of the widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:node_graph_notebook/main.dart';
import 'package:node_graph_notebook/core/services/services.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // 初始化设置服务
    final settingsService = SettingsService();
    await settingsService.init();

    // 初始化主题服务
    final themeService = ThemeService();
    await themeService.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: NodeGraphNotebookApp(
        settingsService: settingsService,
        themeService: themeService,
      ),
    ));

    // Verify that the app starts without errors
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
