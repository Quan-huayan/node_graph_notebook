import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// 主题服务
///
/// 管理应用的主题数据，支持亮色/暗色主题切换和自定义主题
class ThemeService extends ChangeNotifier {
  static const String _customThemeKey = 'custom_theme';
  static const String _useCustomThemeKey = 'use_custom_theme';

  AppThemeData? _customTheme;
  bool _isUsingCustomTheme = false;

  /// 获取当前主题数据
  AppThemeData get themeData => _isUsingCustomTheme && _customTheme != null
      ? _customTheme!
      : AppThemeData.lightTheme;

  /// 是否使用自定义主题
  bool get isUsingCustomTheme => _isUsingCustomTheme;

  /// 根据主题模式获取主题数据
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

  /// 初始化主题服务
  Future<void> init() async {
    await _loadCustomTheme();
  }

  /// 设置自定义主题
  Future<void> setCustomTheme(AppThemeData theme) async {
    _customTheme = theme;
    _isUsingCustomTheme = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customThemeKey, jsonEncode(theme.toJson()));
    await prefs.setBool(_useCustomThemeKey, true);

    notifyListeners();
  }

  /// 重置为预设主题
  Future<void> resetToPreset() async {
    _customTheme = null;
    _isUsingCustomTheme = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customThemeKey);
    await prefs.setBool(_useCustomThemeKey, false);

    notifyListeners();
  }

  /// 加载自定义主题
  Future<void> _loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final useCustom = prefs.getBool(_useCustomThemeKey) ?? false;
    final customThemeJson = prefs.getString(_customThemeKey);

    if (useCustom && customThemeJson != null) {
      try {
        final json = jsonDecode(customThemeJson) as Map<String, dynamic>;
        _customTheme = AppThemeData.fromJson(json);
        _isUsingCustomTheme = true;
      } catch (e) {
        // 如果加载失败，重置为预设主题
        _customTheme = null;
        _isUsingCustomTheme = false;
      }
    }
  }

  /// 更新自定义主题的部分颜色
  Future<void> updateCustomTheme({
    NodeThemeColors? nodes,
    ConnectionThemeColors? connections,
    UIThemeColors? ui,
    TextThemeColors? text,
    BackgroundThemeColors? backgrounds,
    StatusThemeColors? status,
    FlameThemeColors? flame,
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
    );

    await setCustomTheme(updatedTheme);
  }
}
