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
      test('应该使用默认主题初始化', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);
        when(mockPrefs.getString(any)).thenReturn(null);

        await service.init();

        expect(service.isUsingCustomTheme, false);
        expect(service.themeData, AppThemeData.lightTheme);
      });

      test('应该处理无效的自定义主题', () async {
        when(mockPrefs.getBool('use_custom_theme')).thenReturn(true);
        when(mockPrefs.getString('custom_theme')).thenReturn('invalid json');

        await service.init();

        expect(service.isUsingCustomTheme, false);
        expect(service.themeData, AppThemeData.lightTheme);
      });
    });

    group('Theme Data', () {
      test('不使用自定义主题时应该返回亮色主题', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        expect(service.themeData, AppThemeData.lightTheme);
      });

      test('使用自定义主题时应该返回自定义主题', () async {
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
      test('亮色模式应该返回亮色主题', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.light, Brightness.light);

        expect(theme, AppThemeData.lightTheme);
      });

      test('暗色模式应该返回暗色主题', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.dark, Brightness.dark);

        expect(theme, AppThemeData.darkTheme);
      });

      test('系统模式在亮色亮度下应该返回亮色主题', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.system, Brightness.light);

        expect(theme, AppThemeData.lightTheme);
      });

      test('系统模式在暗色亮度下应该返回暗色主题', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.init();

        final theme = service.getThemeForMode(ThemeMode.system, Brightness.dark);

        expect(theme, AppThemeData.darkTheme);
      });

      test('使用自定义主题时任何模式都应该返回自定义主题', () async {
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
      test('应该设置自定义主题', () async {
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

      test('设置自定义主题时应该通知监听器', () async {
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
      test('应该重置为预设主题', () async {
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

      test('重置为预设主题时应该通知监听器', () async {
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
      test('应该部分更新自定义主题', () async {
        final customNodes = AppThemeData.lightTheme.nodes.copyWith(
          nodePrimary: const Color(0xFFFF0000),
        );

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

        await service.updateCustomTheme(nodes: customNodes);

        expect(service.isUsingCustomTheme, true);
        expect(service.themeData.nodes.nodePrimary, const Color(0xFFFF0000));
      });

      test('应该更新多个主题部分', () async {
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

      test('更新自定义主题时应该通知监听器', () async {
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
