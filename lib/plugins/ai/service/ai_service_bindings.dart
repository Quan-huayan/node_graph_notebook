import '../../../../core/plugin/service_binding.dart';
import '../../../../core/services/services.dart';
import 'ai_service.dart';

/// AIService 绑定
///
/// 将 AIService 注册到插件系统的依赖注入容器
/// AIService 是 ChangeNotifier，需要特殊处理
class AIServiceBinding extends ServiceBinding<AIService> {
  @override
  AIService createService(ServiceResolver resolver) {
    final settingsService = resolver.get<SettingsService>();
    final aiService = AIServiceImpl();

    // 初始化 AI 配置
    _updateAIProvider(aiService, settingsService);

    // 监听设置变化
    settingsService.addListener(
      () => _updateAIProvider(aiService, settingsService),
    );

    return aiService;
  }

  void _updateAIProvider(AIService aiService, SettingsService settings) {
    if (settings.isAIConfigured) {
      final provider = settings.aiProvider == 'anthropic'
          ? AnthropicProvider(
              apiKey: settings.aiApiKey!,
              model: settings.aiModel,
              baseUrl: settings.aiBaseUrl,
            )
          : settings.aiProvider == 'zhipuai'
              ? ZhipuAIProvider(
                  apiKey: settings.aiApiKey!,
                  model: settings.aiModel,
                  baseUrl: settings.aiBaseUrl,
                )
              : OpenAIProvider(
                  apiKey: settings.aiApiKey!,
                  model: settings.aiModel,
                  baseUrl: settings.aiBaseUrl,
                );
      aiService.setProvider(provider);
    }
  }

  @override
  /// 清理 AIService 资源
  ///
  /// [service] - 要清理的 AIService 实例
  void dispose(AIService service) {
    // 清理资源（如果需要）
  }
}
