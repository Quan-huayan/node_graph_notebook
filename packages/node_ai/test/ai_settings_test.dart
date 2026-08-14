/// AI 设置测试（M7.2 阶段 C：AI API key 恢复——ConfigAIProvider
/// 按配置委托 Mock/OpenAI，设置表单改 key 即时生效）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ConfigAIProvider：空 key → Mock；配置 key → OpenAI（serviceName）', () async {
    final config = AIProviderConfig();
    final provider = ConfigAIProvider(config);

    // 空 key：Mock 后端（无网络，generate 可跑）。
    expect(provider.serviceName, contains('Mock'));
    final reply = await provider.generate('笔记内容：你好');
    expect(reply, contains('Mock 回复'));

    // 配置 key：OpenAI 后端（serviceName 变化即时生效）。
    config.setApiKey('sk-test-key');
    expect(provider.serviceName, contains('OpenAI'));
    expect(config.apiKey, 'sk-test-key');
  });

  test('AIProviderConfig：setApiKey 通知监听（表单即时刷新）', () {
    final config = AIProviderConfig();
    var notified = 0;
    config.addListener(() => notified++);

    config.setApiKey('  sk-1  ');

    expect(notified, 1);
    expect(config.apiKey, 'sk-1'); // trim。
  });

  test('AIProviderConfig 持久化：setter 保存 → 新实例 attach 恢复（P1-1）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final first = AIProviderConfig()..attach(prefs);
    first
      ..setApiKey('sk-persisted')
      ..setModel('gpt-4o')
      ..setBaseUrl('https://proxy.example.com/v1');
    expect(prefs.getString('ai.apiKey'), 'sk-persisted');
    expect(prefs.getString('ai.model'), 'gpt-4o');
    expect(prefs.getString('ai.baseUrl'), 'https://proxy.example.com/v1');

    // 模拟重启：新实例 + 同一 prefs → 恢复上次配置。
    final second = AIProviderConfig()..attach(prefs);
    expect(second.apiKey, 'sk-persisted');
    expect(second.model, 'gpt-4o');
    expect(second.baseUrl, 'https://proxy.example.com/v1');
  });
}
