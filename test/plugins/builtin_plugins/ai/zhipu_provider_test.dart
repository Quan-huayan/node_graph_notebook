import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/ai/service/ai_service.dart';

void main() {
  group('ZhipuAIProvider', () {
    test('should have correct service name', () {
      final provider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      );

      expect(provider.serviceName, '智谱AI (glm-4)');
    });

    test('should handle glm-4-plus model', () {
      final glm4PlusProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4-plus',
      );

      expect(glm4PlusProvider.serviceName, '智谱AI (glm-4-plus)');
      expect(glm4PlusProvider.model, 'glm-4-plus');
    });

    test('should handle glm-4-air model', () {
      final glm4AirProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4-air',
      );

      expect(glm4AirProvider.serviceName, '智谱AI (glm-4-air)');
      expect(glm4AirProvider.model, 'glm-4-air');
    });

    test('should handle glm-4-flash model', () {
      final glm4FlashProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4-flash',
      );

      expect(glm4FlashProvider.serviceName, '智谱AI (glm-4-flash)');
      expect(glm4FlashProvider.model, 'glm-4-flash');
    });

    test('should handle custom base URL', () {
      final customProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4',
        baseUrl: 'https://custom-endpoint.com/api/v1',
      );

      expect(customProvider.baseUrl, 'https://custom-endpoint.com/api/v1');
    });

    test('should handle default values', () {
      final defaultProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
      );

      expect(defaultProvider.model, 'glm-4');
      expect(defaultProvider.maxTokens, 2000);
      expect(
        defaultProvider.baseUrl,
        'https://open.bigmodel.cn/api/paas/v4',
      );
    });

    test('should handle custom maxTokens', () {
      final customTokensProvider = ZhipuAIProvider(
        apiKey: 'test-api-key',
        model: 'glm-4',
        maxTokens: 4000,
      );

      expect(customTokensProvider.maxTokens, 4000);
    });

    test('should store API key', () {
      final provider = ZhipuAIProvider(
        apiKey: 'my-secret-api-key',
      );

      expect(provider.apiKey, 'my-secret-api-key');
    });
  });
}
