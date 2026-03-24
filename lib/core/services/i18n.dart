import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n/translations.dart'; // 导入生成的翻译数据

/// 国际化服务
///
/// 提供多语言支持，通过插件动态更新翻译
/// 支持语言持久化，重启应用后自动恢复上次选择的语言
///
/// 架构说明：
/// - 翻译数据从外部 CSV 文件生成，存储在 translations.dart
/// - 支持动态扩展翻译（通过 addTranslation 等方法）
/// - 语言设置持久化到 SharedPreferences
class I18n extends ChangeNotifier {
  /// 单例实例
  I18n();

  /// 获取当前上下文的 I18n 实例
  static I18n of(BuildContext context) => Provider.of<I18n>(context, listen: false);

  /// SharedPreferences 存储键
  static const String _prefsKey = 'i18n_language';

  /// 默认语言
  static const String _defaultLanguage = 'en';

  String _currentLanguage = _defaultLanguage;
  bool _isInitialized = false;

  /// 动态翻译数据（插件添加的翻译）
  final Map<String, Map<String, String>> _dynamicTranslations = {
    'en': {},
    'zh': {},
  };

  /// 当前语言
  String get currentLanguage => _currentLanguage;

  /// 是否已初始化（从持久化存储加载）
  bool get isInitialized => _isInitialized;

  /// 初始化语言设置
  ///
  /// 从 SharedPreferences 加载用户上次选择的语言
  /// 如果没有保存的语言，使用默认语言
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_prefsKey);

      if (savedLanguage != null && supportsLanguage(savedLanguage)) {
        _currentLanguage = savedLanguage;
        debugPrint('[I18n] Loaded saved language: $_currentLanguage');
      } else {
        debugPrint('[I18n] Using default language: $_currentLanguage');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[I18n] Failed to load saved language: $e');
      _isInitialized = true;
    }
  }

  /// 翻译文本
  ///
  /// [key] 翻译键（通常是英文原文）
  /// 返回翻译后的文本，如果找不到翻译则返回原文本
  ///
  /// 查找顺序：
  /// 1. 动态翻译（插件添加的）
  /// 2. 静态翻译（从 CSV 生成的）
  /// 3. 原文本（优雅降级）
  String t(String key) {
    // 先查找动态翻译（优先级更高，允许插件覆盖）
    final dynamicLangMap = _dynamicTranslations[_currentLanguage];
    if (dynamicLangMap != null && dynamicLangMap.containsKey(key)) {
      return dynamicLangMap[key]!;
    }

    // 再查找静态翻译
    final staticLangMap = I18nTranslations.data[_currentLanguage];
    if (staticLangMap != null && staticLangMap.containsKey(key)) {
      return staticLangMap[key]!;
    }

    // 找不到翻译，返回原文本
    return key;
  }

  /// 切换语言
  ///
  /// [language] 语言代码（'en' 或 'zh'）
  /// 会自动保存到 SharedPreferences，下次启动时自动恢复
  Future<void> switchLanguage(String language) async {
    if (_currentLanguage == language) return;

    if (!supportsLanguage(language)) {
      debugPrint('[I18n] Unsupported language: $language');
      return;
    }

    _currentLanguage = language;
    notifyListeners();
    debugPrint('[I18n] Language switched to: $language');

    // 持久化语言选择
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language);
      debugPrint('[I18n] Language saved to preferences');
    } catch (e) {
      debugPrint('[I18n] Failed to save language: $e');
    }
  }

  /// 检查是否支持指定语言
  bool supportsLanguage(String language) {
    return I18nTranslations.data.containsKey(language);
  }

  /// 获取所有支持的语言
  List<String> get supportedLanguages => I18nTranslations.data.keys.toList();

  /// 更新翻译数据（动态）
  ///
  /// [translations] 新的翻译数据
  /// 注意：此方法只更新动态翻译，不会修改生成的静态翻译
  void updateTranslations(Map<String, Map<String, String>> translations) {
    translations.forEach(addTranslations);
    notifyListeners();
  }

  /// 添加或更新动态翻译
  ///
  /// [language] 语言代码
  /// [key] 翻译键
  /// [value] 翻译值
  ///
  /// 动态翻译的优先级高于静态翻译，允许插件覆盖默认翻译
  void addTranslation(String language, String key, String value) {
    if (!_dynamicTranslations.containsKey(language)) {
      _dynamicTranslations[language] = {};
    }
    _dynamicTranslations[language]![key] = value;
  }

  /// 批量添加动态翻译
  ///
  /// [language] 语言代码
  /// [translations] 翻译映射
  void addTranslations(String language, Map<String, String> translations) {
    if (!_dynamicTranslations.containsKey(language)) {
      _dynamicTranslations[language] = {};
    }
    _dynamicTranslations[language]!.addAll(translations);
  }

  /// 获取翻译统计信息
  Map<String, int> getTranslationStats() {
    final stats = <String, int>{};

    for (final lang in supportedLanguages) {
      final staticCount = I18nTranslations.data[lang]?.length ?? 0;
      final dynamicCount = _dynamicTranslations[lang]?.length ?? 0;
      stats[lang] = staticCount + dynamicCount;
    }

    return stats;
  }

  @override
  String toString() => 'I18n(language: $_currentLanguage)';
}
