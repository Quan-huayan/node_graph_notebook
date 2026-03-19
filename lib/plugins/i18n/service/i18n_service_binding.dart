import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../../../core/plugin/service_binding.dart';
import '../../../../core/services/i18n.dart';

/// I18nService 绑定
///
/// 将 I18n 服务注册到插件系统的依赖注入容器
///
/// 架构说明：
/// - I18n 是全局单例服务，提供多语言支持
/// - 通过插件系统注册，确保正确的依赖注入顺序
/// - 无需额外依赖，独立运行
/// - 服务创建后会自动初始化，加载用户上次选择的语言
/// - 使用 ChangeNotifierProvider 因为 I18n 继承了 ChangeNotifier
class I18nServiceBinding extends ServiceBinding<I18n> {
  @override
  I18n createService(ServiceResolver resolver) {
    // 创建 I18n 实例
    final i18n = I18n();

    // 异步初始化，从持久化存储加载语言设置
    // 不阻塞服务创建，初始化在后台进行
    i18n.initialize().catchError((error) {
      // 初始化失败不影响服务创建，使用默认语言
      debugPrint('[I18nServiceBinding] Failed to initialize: $error');
    });

    return i18n;
  }

  @override
  bool get isSingleton => true;

  @override
  bool get isLazy => false;

  @override
  SingleChildWidget createProvider(I18n instance) =>
      // I18n 继承了 ChangeNotifier，必须使用 ChangeNotifierProvider
      // 而不是普通的 Provider，否则会出现 "Tried to use Provider with a subtype of Listenable" 错误
      ChangeNotifierProvider<I18n>.value(
        value: instance,
      );
}
