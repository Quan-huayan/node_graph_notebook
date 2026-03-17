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
      test('should have default values', () {
        expect(service.themeMode, ThemeMode.system);
        expect(service.defaultViewMode, null);
        expect(service.aiProvider, 'openai');
        expect(service.aiBaseUrl, 'https://api.openai.com/v1');
        expect(service.aiModel, 'gpt-4');
        expect(service.aiApiKey, null);
      });
    });

    group('Theme Mode', () {
      test('should have theme mode property', () {
        expect(service.themeMode, ThemeMode.system);
      });
    });

    group('Default View Mode', () {
      test('should have default view mode property', () {
        expect(service.defaultViewMode, null);
      });
    });

    group('AI Configuration', () {
      test('should have AI provider property', () {
        expect(service.aiProvider, 'openai');
      });

      test('should have AI base URL property', () {
        expect(service.aiBaseUrl, 'https://api.openai.com/v1');
      });

      test('should have AI model property', () {
        expect(service.aiModel, 'gpt-4');
      });

      test('should have AI API key property', () {
        expect(service.aiApiKey, null);
      });
    });
  });
}
