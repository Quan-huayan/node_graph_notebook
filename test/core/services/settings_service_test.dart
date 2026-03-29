import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/settings_service.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('SettingsService', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
    });

    group('Initialization', () {
      test('应该具有默认值', () {
        expect(service.themeMode, ThemeMode.system);
        expect(service.defaultViewMode, null);
        expect(service.aiProvider, 'openai');
        expect(service.aiBaseUrl, 'https://api.openai.com/v1');
        expect(service.aiModel, 'gpt-4');
        expect(service.aiApiKey, null);
      });
    });

    group('Theme Mode', () {
      test('应该具有主题模式属性', () {
        expect(service.themeMode, ThemeMode.system);
      });
    });

    group('Default View Mode', () {
      test('应该具有默认视图模式属性', () {
        expect(service.defaultViewMode, null);
      });
    });

    group('AI Configuration', () {
      test('应该具有 AI 提供商属性', () {
        expect(service.aiProvider, 'openai');
      });

      test('应该具有 AI 基础 URL 属性', () {
        expect(service.aiBaseUrl, 'https://api.openai.com/v1');
      });

      test('应该具有 AI 模型属性', () {
        expect(service.aiModel, 'gpt-4');
      });

      test('应该具有 AI API 密钥属性', () {
        expect(service.aiApiKey, null);
      });
    });
  });
}
