/// I18nPlugin —— 语言设置插件（M7，01 拍板 #38；M7.2 上移壳层修正）。
///
/// **I18nService 上移 appframe（壳层）**：语言包全局可达（插件互不依赖
/// 的根因修正——服务在插件里其他插件/壳层无法解析，"语言设置形同
/// 虚设"）。本插件 = 语言设置条目 Concept（kind == 'settings-i18n'，
/// 聚合归设置容器——references 反查），编辑壳层服务。
library;

import 'package:core/core.dart';
import 'package:plugon/plugon.dart';

import 'src/i18n_settings.dart';

/// 语言设置插件。
class I18nPlugin extends Plugin {
  /// 插件实例。
  I18nPlugin();

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.i18n',
    name: '国际化插件',
    version: '1.0.0',
  );

  @override
  void registerExtensions(ExtensionRegistry registry) {
    // M7.2 阶段 C：语言设置条目。
    registry.addContribution(
      conceptPoint,
      const I18nSettingsConcept(),
      ownerPluginId: metadata.id,
    );
  }
}
