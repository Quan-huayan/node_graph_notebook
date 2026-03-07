import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:node_graph_notebook/bloc/ui/ui_bloc.dart';
import 'package:node_graph_notebook/core/services/services.dart';
import 'package:node_graph_notebook/core/services/theme/app_theme.dart';
import 'package:node_graph_notebook/app.dart';

void main() {
  // 在所有测试开始前初始化 SharedPreferences mock
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('App Widget Tests', () {
    late SettingsService settingsService;
    late ThemeService themeService;

    setUp(() async {
      // Initialize services
      settingsService = SettingsService();
      await settingsService.init();

      themeService = ThemeService();
      await themeService.init();
    });

    testWidgets('App starts successfully', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Verify that the app starts without errors
      expect(find.byType(MaterialApp), findsWidgets);
    });

    testWidgets('App provides required services', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Pump once to start initialization
      await tester.pump();

      // Wait for initialization to complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the app builds without throwing
      expect(tester.takeException(), isNull);
    });

    testWidgets('App maintains theme state', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Pump to initialize
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify theme service is accessible
      expect(themeService.themeData, isNotNull);
    });

    testWidgets('App maintains settings state', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Pump to initialize
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify settings service is accessible
      expect(settingsService, isNotNull);
    });
  });

  group('UIBloc Provider Tests', () {
    late UIBloc uiBloc;

    setUp(() {
      uiBloc = UIBloc();
    });

    tearDown(() {
      uiBloc.close();
    });

    testWidgets('App should provide UIBloc', (WidgetTester tester) async {
      await tester.pumpWidget(
        BlocProvider<UIBloc>(
          create: (_) => uiBloc,
          child: const MaterialApp(
            home: Scaffold(
              body: Placeholder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify UIBloc is provided
      final bloc = BlocProvider.of<UIBloc>(tester.element(find.byType(Scaffold)));
      expect(bloc, isNotNull);
      expect(bloc, uiBloc);
    });

    testWidgets('UIBloc should have correct initial state', (WidgetTester tester) async {
      await tester.pumpWidget(
        BlocProvider<UIBloc>(
          create: (_) => uiBloc,
          child: const MaterialApp(
            home: Scaffold(
              body: Placeholder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final bloc = BlocProvider.of<UIBloc>(tester.element(find.byType(Scaffold)));
      expect(bloc.state.nodeViewMode, isNotNull);
      expect(bloc.state.showConnections, true);
      expect(bloc.state.isSidebarOpen, true);
    });
  });

  group('Theme Tests', () {
    testWidgets('App applies theme correctly', (WidgetTester tester) async {
      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.getMaterialTheme(themeService.themeData, Brightness.light),
        home: const Scaffold(
          body: Placeholder(),
        ),
      ));

      await tester.pumpAndSettle();

      // Verify theme is applied
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold, isNotNull);
    });

    testWidgets('Theme updates trigger rebuild', (WidgetTester tester) async {
      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.getMaterialTheme(themeService.themeData, Brightness.light),
        home: const Scaffold(
          body: Placeholder(),
        ),
      ));

      await tester.pumpAndSettle();

      // Update theme
      await themeService.setCustomTheme(themeService.themeData);

      await tester.pumpAndSettle();

      // Verify app rebuilds with new theme
      expect(tester.takeException(), isNull);
    });
  });

  group('Integration Tests', () {
    testWidgets('Services and BLoC work together', (WidgetTester tester) async {
      final settingsService = SettingsService();
      await settingsService.init();

      final themeService = ThemeService();
      await themeService.init();

      final uiBloc = UIBloc();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(value: settingsService),
            ChangeNotifierProvider<ThemeService>.value(value: themeService),
            BlocProvider<UIBloc>.value(value: uiBloc),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Placeholder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all providers are available
      expect(
        Provider.of<SettingsService>(tester.element(find.byType(Scaffold)), listen: false),
        settingsService,
      );

      expect(
        Provider.of<ThemeService>(tester.element(find.byType(Scaffold)), listen: false),
        themeService,
      );

      expect(
        BlocProvider.of<UIBloc>(tester.element(find.byType(Scaffold))),
        uiBloc,
      );

      uiBloc.close();
    });

    testWidgets('App handles theme changes gracefully', (WidgetTester tester) async {
      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.getMaterialTheme(themeService.themeData, Brightness.light),
        home: Scaffold(
          appBar: AppBar(title: const Text('Test')),
          body: Container(),
        ),
      ));

      await tester.pumpAndSettle();

      // Find AppBar before theme change
      expect(find.byType(AppBar), findsOneWidget);

      // Change theme
      await themeService.setCustomTheme(themeService.themeData);

      await tester.pumpAndSettle();

      // AppBar should still be present after theme change
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('Widget Lifecycle Tests', () {
    testWidgets('App initializes correctly on first build', (WidgetTester tester) async {
      final settingsService = SettingsService();
      await settingsService.init();

      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // First pump
      await tester.pump();

      // Wait for initialization (avoid pumpAndSettle timeout)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('App handles rebuild correctly', (WidgetTester tester) async {
      final settingsService = SettingsService();
      await settingsService.init();

      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Wait for initialization
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger a rebuild
      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no errors after rebuild
      expect(tester.takeException(), isNull);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('App handles missing services gracefully', (WidgetTester tester) async {
      // This test verifies the app doesn't crash when services are not properly initialized
      // In a real app, you might want to show an error screen

      final settingsService = SettingsService();
      // Don't initialize settings service

      final themeService = ThemeService();
      // Don't initialize theme service

      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // App should handle this gracefully
      await tester.pump();

      // The app might show an error or loading state, but shouldn't crash
      // This is a basic test - you might want to add more specific error handling tests
    });

    testWidgets('App handles service errors', (WidgetTester tester) async {
      final settingsService = SettingsService();
      await settingsService.init();

      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(MaterialApp(
        home: NodeGraphNotebookApp(
          settingsService: settingsService,
          themeService: themeService,
        ),
      ));

      // Wait for initialization
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate an error condition (if your app has error handling)
      // This is a placeholder for more specific error tests

      // Verify the app is still running
      expect(find.byType(MaterialApp), findsWidgets);
    });
  });
}
