import '../../../../core/plugin/service_binding.dart';
import '../../../../core/services/services.dart';
import 'ai_service.dart';

/// AIService 绑定
///
/// 将 AIService 注册到插件系统的依赖注入容器
/// AIService 是 ChangeNotifier，需要特殊处理
class AIServiceBinding extends ServiceBinding<AIService> {
  SettingsService? _settingsService;
  void Function()? _listener;

  @override
  AIService createService(ServiceResolver resolver) {
    final settingsService = resolver.get<SettingsService>();
    final aiService = AIServiceImpl();

    // 保存引用以便后续清理
    _settingsService = settingsService;

    // 初始化 AI 配置
    _updateAIProvider(aiService, settingsService);

    // 创建监听器并保存引用
    _listener = () => _updateAIProvider(aiService, settingsService);
    settingsService.addListener(_listener!);

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
    // 移除监听器以防止内存泄漏
    if (_settingsService != null && _listener != null) {
      _settingsService!.removeListener(_listener!);
    }
    _settingsService = null;
    _listener = null;
  }
}
