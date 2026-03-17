import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/services/theme/app_theme.dart';
import 'package:node_graph_notebook/core/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_service_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('ThemeService', () {
    late ThemeService service;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      SharedPreferences.setMockInitialValues({});
      service = ThemeService();
    });

    group('Initialization', () {
      test('should initialize with default theme', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);
        when(mockPrefs.getString(any)).thenReturn(null);

        await service.init();

        expect(service.isUsingCustomTheme, false);
        expect(service.themeData, AppThemeData.lightTheme);
      });

      test('should handle invalid custom theme', () async {
        when(mockPrefs.getBool('use_custom_theme')).thenReturn(true);
        when(mockPrefs.getString('custom_theme')).thenReturn('invalid json');

        await service.init();

        expect(service.isUsingCustomTheme, false);
        expect(service.themeData, AppThemeData.lightTheme);
      });
    });

    group('Theme Data', () {
      test('should return light theme when not using custom theme', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        expect(service.themeData, AppThemeData.lightTheme);
      });

      test('should return custom theme when using custom theme', () async {
        final customTheme = AppThemeData.lightTheme.copyWith(
          nodes: AppThemeData.lightTheme.nodes.copyWith(
            nodePrimary: const Color(0xFFFF0000),
          ),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.setCustomTheme(customTheme);

        expect(service.themeData.nodes.nodePrimary, const Color(0xFFFF0000));
      });
    });

    group('Theme Mode', () {
      test('should return light theme for light mode', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.light, Brightness.light);

        expect(theme, AppThemeData.lightTheme);
      });

      test('should return dark theme for dark mode', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.dark, Brightness.dark);

        expect(theme, AppThemeData.darkTheme);
      });

      test('should return light theme for system mode with light brightness', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.system, Brightness.light);

        expect(theme, AppThemeData.lightTheme);
      });

      test('should return dark theme for system mode with dark brightness', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.system, Brightness.dark);

        expect(theme, AppThemeData.darkTheme);
      });

      test('should return custom theme for any mode when using custom theme', () async {
        final customTheme = AppThemeData.lightTheme.copyWith(
          nodes: AppThemeData.lightTheme.nodes.copyWith(
            nodePrimary: const Color(0xFFFF0000),
          ),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.setCustomTheme(customTheme);

        final lightTheme = service.getThemeForMode(ThemeMode.light, Brightness.light);
        final darkTheme = service.getThemeForMode(ThemeMode.dark, Brightness.dark);
        final systemTheme = service.getThemeForMode(ThemeMode.system, Brightness.light);

        expect(lightTheme.nodes.nodePrimary, const Color(0xFFFF0000));
        expect(darkTheme.nodes.nodePrimary, const Color(0xFFFF0000));
        expect(systemTheme.nodes.nodePrimary, const Color(0xFFFF0000));
      });
    });

    group('Set Custom Theme', () {
      test('should set custom theme', () async {
        final customTheme = AppThemeData.lightTheme.copyWith(
          nodes: AppThemeData.lightTheme.nodes.copyWith(
            nodePrimary: const Color(0xFFFF0000),
          ),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.setCustomTheme(customTheme);

        expect(service.isUsingCustomTheme, true);
        expect(service.themeData.nodes.nodePrimary, const Color(0xFFFF0000));
      });

      test('should notify listeners when setting custom theme', () async {
        const customTheme = AppThemeData.lightTheme;
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        var notified = false;
        service.addListener(() {
          notified = true;
        });

        await service.setCustomTheme(customTheme);

        expect(notified, true);
      });
    });

    group('Reset to Preset', () {
      test('should reset to preset theme', () async {
        final customTheme = AppThemeData.lightTheme.copyWith(
          nodes: AppThemeData.lightTheme.nodes.copyWith(
            nodePrimary: const Color(0xFFFF0000),
          ),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        await service.setCustomTheme(customTheme);
        await service.resetToPreset();

        expect(service.isUsingCustomTheme, false);
        expect(service.themeData, AppThemeData.lightTheme);
      });

      test('should notify listeners when resetting to preset', () async {
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        var notified = false;
        service.addListener(() {
          notified = true;
        });

        await service.resetToPreset();

        expect(notified, true);
      });
    });

    group('Update Custom Theme', () {
      test('should update custom theme partially', () async {
        final customNodes = AppThemeData.lightTheme.nodes.copyWith(
          nodePrimary: const Color(0xFFFF0000),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.updateCustomTheme(nodes: customNodes);

        expect(service.isUsingCustomTheme, true);
        expect(service.themeData.nodes.nodePrimary, const Color(0xFFFF0000));
      });

      test('should update multiple theme parts', () async {
        final customNodes = AppThemeData.lightTheme.nodes.copyWith(
          nodePrimary: const Color(0xFFFF0000),
        );
        final customConnections = AppThemeData.lightTheme.connections.copyWith(
          contains: const Color(0x00FF00FF),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.updateCustomTheme(
          nodes: customNodes,
          connections: customConnections,
        );

        expect(service.themeData.nodes.nodePrimary, const Color(0xFFFF0000));
        expect(service.themeData.connections.contains, const Color(0x00FF00FF));
      });

      test('should notify listeners when updating custom theme', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        var notified = false;
        service.addListener(() {
          notified = true;
        });

        await service.updateCustomTheme(
          nodes: AppThemeData.lightTheme.nodes,
        );

        expect(notified, true);
      });
    });
  });
}
