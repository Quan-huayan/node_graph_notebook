import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// 主题服务
///
/// 管理应用主题设置，包括自定义主题、主题模式切换和持久化
class ThemeService extends ChangeNotifier {
  /// 自定义主题的存储键
  static const String _customThemeKey = 'custom_theme';
  
  /// 是否使用自定义主题的存储键
  static const String _useCustomThemeKey = 'use_custom_theme';
  
  /// 主题模式的存储键
  static const String _themeModeKey = 'theme_mode';

  AppThemeData? _customTheme;
  bool _isUsingCustomTheme = false;
  ThemeMode _themeMode = ThemeMode.system;

  /// 获取当前主题数据
  ///
  /// 如果启用了自定义主题则返回自定义主题，否则返回默认主题
  AppThemeData get themeData => _isUsingCustomTheme && _customTheme != null
      ? _customTheme!
      : AppThemeData.lightTheme;

  /// 是否正在使用自定义主题
  bool get isUsingCustomTheme => _isUsingCustomTheme;

  /// 获取当前主题模式
  ThemeMode get themeMode => _themeMode;

  /// 根据主题模式获取对应的主题数据
  ///
  /// [mode] 主题模式
  /// [systemBrightness] 系统亮度
  ///
  /// 返回：对应模式的主题数据
  AppThemeData getThemeForMode(ThemeMode mode, Brightness systemBrightness) {
    if (_isUsingCustomTheme && _customTheme != null) {
      return _customTheme!;
    }

    switch (mode) {
      case ThemeMode.light:
        return AppThemeData.lightTheme;
      case ThemeMode.dark:
        return AppThemeData.darkTheme;
      case ThemeMode.system:
        return systemBrightness == Brightness.dark
            ? AppThemeData.darkTheme
            : AppThemeData.lightTheme;
    }
  }

  /// 获取当前主题数据（包含系统模式）
  ///
  /// 返回：当前主题数据，考虑系统亮度
  AppThemeData get currentThemeData => getThemeForMode(
    _themeMode,
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  /// 初始化主题服务
  ///
  /// 从持久化存储加载主题设置
  Future<void> init() async {
    await _loadCustomTheme();
    await _loadThemeMode();
  }

  /// 设置主题模式
  ///
  /// [mode] 要设置的主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
    notifyListeners();
  }

  /// 设置自定义主题
  ///
  /// [theme] 要设置的自定义主题数据
  Future<void> setCustomTheme(AppThemeData theme) async {
    _customTheme = theme;
    _isUsingCustomTheme = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customThemeKey, jsonEncode(theme.toJson()));
    await prefs.setBool(_useCustomThemeKey, true);

    notifyListeners();
  }

  /// 重置为预设主题
  ///
  /// 清除自定义主题设置并恢复到默认主题
  Future<void> resetToPreset() async {
    _customTheme = null;
    _isUsingCustomTheme = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customThemeKey);
    await prefs.setBool(_useCustomThemeKey, false);

    notifyListeners();
  }

  Future<void> _loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final useCustom = prefs.getBool(_useCustomThemeKey) ?? false;
    final customThemeJson = prefs.getString(_customThemeKey);

    if (useCustom && customThemeJson != null) {
      try {
        final json = jsonDecode(customThemeJson) as Map<String, dynamic>;
        _customTheme = AppThemeData.fromJson(json);
        _isUsingCustomTheme = true;
      } catch (_) {
        _customTheme = null;
        _isUsingCustomTheme = false;
      }
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeStr = prefs.getString(_themeModeKey);
    if (themeModeStr != null) {
      _themeMode = _parseThemeMode(themeModeStr);
    }
  }

  ThemeMode _parseThemeMode(String modeStr) {
    switch (modeStr) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 更新自定义主题
  ///
  /// 根据提供的参数更新当前自定义主题的部分或全部属性
  ///
  /// [nodes] 节点主题颜色
  /// [connections] 连线主题颜色
  /// [ui] UI 主题颜色
  /// [text] 文本主题颜色
  /// [backgrounds] 背景主题颜色
  /// [status] 状态主题颜色
  /// [flame] Flame 主题颜色
  /// [sidebar] 侧边栏主题颜色
  /// [fontFamily] 字体家族
  Future<void> updateCustomTheme({
    NodeThemeColors? nodes,
    ConnectionThemeColors? connections,
    UIThemeColors? ui,
    TextThemeColors? text,
    BackgroundThemeColors? backgrounds,
    StatusThemeColors? status,
    FlameThemeColors? flame,
    SidebarThemeColors? sidebar,
    String? fontFamily,
  }) async {
    final currentTheme = _customTheme ?? AppThemeData.lightTheme;

    final updatedTheme = currentTheme.copyWith(
      nodes: nodes,
      connections: connections,
      ui: ui,
      text: text,
      backgrounds: backgrounds,
      status: status,
      flame: flame,
      sidebar: sidebar,
      fontFamily: fontFamily,
    );

    await setCustomTheme(updatedTheme);
  }
}
