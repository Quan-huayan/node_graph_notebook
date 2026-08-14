import 'settings_registry.dart';

/// 核心设置定义
///
/// 定义应用程序的核心设置项，包括主题模式、默认视图模式等
class CoreSettings {
  /// 注册核心设置到 SettingsRegistry
  ///
  /// 在 SettingsRegistry 初始化时调用，注册所有核心设置项
  static void register(SettingsRegistry registry) {
    registry
      ..register(SettingDefinition<String>(
        key: 'core.themeMode',
        defaultValue: 'system',
        displayName: 'Theme Mode',
        description: 'Application theme mode (light, dark, system)',
        category: 'Core',
        validator: (value) =>
            ['light', 'dark', 'system'].contains(value) ? value : 'system',
      ))
      ..register(const SettingDefinition<String?>(
        key: 'core.defaultViewMode',
        defaultValue: null,
        displayName: 'Default View Mode',
        description: 'Default node view mode',
        category: 'Core',
      ));
  }
}
