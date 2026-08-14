/// I18nService —— 国际化服务（M7，01 拍板 #38；M7.2 上移 appframe）。
///
/// **壳层概念**（同 ThemeController，E3 模式）：全局文案的服务归壳层，
/// 所有插件经 plugon DI 解析（插件互不依赖，04 §三 约束 3——语言包在
/// 插件里其他插件不可达，即"语言设置形同虚设"的根因）。node_i18n
/// 插件 = 语言设置条目（编辑本服务）。
///
/// ChangeNotifier：语言切换即时通知（壳层/表单重建）。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

/// 国际化服务。
///
/// P1-1：持久化绑定——[attach] 注入 SharedPreferences（app 层提供）
/// 后，读回上次语言并随切换自动保存；null = 纯内存。验收 = 重启后
/// 语言保持（00 §4.2 判据）。
class I18nService extends ChangeNotifier {
  /// 构造（缺省中文）。
  I18nService({this.language = AppLanguage.zh});

  /// 当前语言。
  AppLanguage language;

  static const String _kLanguage = 'settings.language';

  SharedPreferences? _prefs;

  /// 绑定持久化并恢复上次语言（HostRuntime 构造时调用）。
  void attach(SharedPreferences? prefs) {
    _prefs = prefs;
    if (prefs == null) {
      return;
    }
    final saved = prefs.getString(_kLanguage);
    if (saved != null) {
      final parsed = AppLanguage.values.firstWhere(
        (l) => l.name == saved,
        orElse: () => AppLanguage.zh,
      );
      if (parsed != language) {
        language = parsed;
        notifyListeners();
      }
    }
  }

  /// 翻译（缺失键回退英文 → 键本身）。
  String t(String key) {
    final table = language == AppLanguage.zh ? zhTranslations : enTranslations;
    final value = table[key];
    if (value != null) {
      return value;
    }
    return enTranslations[key] ?? key;
  }

  /// 切换语言（通知监听者——UI 即时重建；已绑定则持久化）。
  void setLanguage(AppLanguage value) {
    if (language == value) {
      return;
    }
    language = value;
    _prefs?.setString(_kLanguage, value.name);
    notifyListeners();
  }
}
