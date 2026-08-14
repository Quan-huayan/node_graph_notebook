/// ThemeController —— 壳层主题控制器（M7.2，E3 实施缺口修复）。
///
/// 拍板 #39："app 组合根读取并应用到 MaterialApp"——主题状态是**壳层
/// 概念**（MaterialApp 在 appframe）：本控制器由 HostRuntime 持有并注册
/// 为 plugon 服务，设置插件（node_settings）经 DI 解析后编辑，NotebookApp
/// 消费并响应运行时切换（ListenableBuilder）。MVP 内存态（持久化 =
/// SharedPreferences 由 app 层提供，阶段 C 设置容器化时迭代）。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式。
enum AppThemeMode {
  /// 跟随系统。
  system,

  /// 明亮。
  light,

  /// 暗黑。
  dark,
}

/// 主题控制器（ChangeNotifier——运行时切换即时生效）。
///
/// P1-1：持久化绑定——[attach] 注入 SharedPreferences（app 层提供，
/// 拍板 #50"SharedPreferences 由 app 层提供"）后，读回上次值并
/// 在每次 setter 自动保存。null = 纯内存（测试/无持久化场景）。
/// 验收 = 重启后主题/字体保持（00 §4.2 判据）。
class ThemeController extends ChangeNotifier {
  /// 构造（缺省跟随系统、文字缩放 1.0、字体族 null = 平台默认）。
  ThemeController({
    this.mode = AppThemeMode.system,
    this.textScale = 1.0,
    this.fontFamily,
  });

  /// 当前主题模式。
  AppThemeMode mode;

  /// 文字缩放（1.0 默认；M7.2 字体设置条目可调）。
  double textScale;

  /// 字体族（null = 平台默认；M7.2 字体设置条目可调——具体字体切换）。
  String? fontFamily;

  static const String _kMode = 'settings.themeMode';
  static const String _kTextScale = 'settings.textScale';
  static const String _kFontFamily = 'settings.fontFamily';

  SharedPreferences? _prefs;

  /// 绑定持久化并恢复上次值（HostRuntime 构造时调用）。
  void attach(SharedPreferences? prefs) {
    _prefs = prefs;
    if (prefs == null) {
      return;
    }
    final savedMode = prefs.getString(_kMode);
    if (savedMode != null) {
      mode = AppThemeMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => AppThemeMode.system,
      );
    }
    textScale = prefs.getDouble(_kTextScale) ?? textScale;
    fontFamily = prefs.getString(_kFontFamily) ?? fontFamily;
    notifyListeners();
  }

  /// 切换主题（通知 MaterialApp 重建；已绑定则持久化）。
  void setMode(AppThemeMode value) {
    mode = value;
    _prefs?.setString(_kMode, value.name);
    notifyListeners();
  }

  /// 设置文字缩放（通知 MaterialApp 经 MediaQuery 应用；已绑定则持久化）。
  void setTextScale(double value) {
    textScale = value;
    _prefs?.setDouble(_kTextScale, value);
    notifyListeners();
  }

  /// 设置字体族（通知 MaterialApp 主题应用；已绑定则持久化）。
  void setFontFamily(String? value) {
    fontFamily = value;
    if (value == null) {
      _prefs?.remove(_kFontFamily);
    } else {
      _prefs?.setString(_kFontFamily, value);
    }
    notifyListeners();
  }
}
