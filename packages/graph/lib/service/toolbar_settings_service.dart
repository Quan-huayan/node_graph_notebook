import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 工具栏固定位置枚举
enum ToolbarPosition {
  /// 左上角
  topLeft,

  /// 右上角
  topRight,

  /// 左下角
  bottomLeft,

  /// 右下角
  bottomRight,
}

/// 工具栏位置设置
///
/// 存储工具栏的位置和固定状态
class ToolbarPositionSetting {
  /// 创建工具栏位置设置
  ///
  /// [position] 工具栏位置坐标
  /// [isPinned] 是否固定到预设位置
  /// [pinPosition] 固定位置（当isPinned为true时有效）
  const ToolbarPositionSetting({
    this.position = const Offset(16, 80),
    this.isPinned = false,
    this.pinPosition = ToolbarPosition.topLeft,
  });

  /// 从JSON创建实例
  factory ToolbarPositionSetting.fromJson(Map<String, dynamic> json) =>
      ToolbarPositionSetting(
        position: Offset(json['dx'] as double, json['dy'] as double),
        isPinned: json['isPinned'] as bool? ?? false,
        pinPosition: ToolbarPosition.values.firstWhere(
          (e) => e.name == json['pinPosition'],
          orElse: () => ToolbarPosition.topLeft,
        ),
      );

  /// 工具栏位置坐标
  final Offset position;

  /// 是否固定到预设位置
  final bool isPinned;

  /// 固定位置（当isPinned为true时有效）
  final ToolbarPosition pinPosition;

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
    'dx': position.dx,
    'dy': position.dy,
    'isPinned': isPinned,
    'pinPosition': pinPosition.name,
  };
}

/// 工具栏设置服务
///
/// 负责持久化工具栏位置设置
///
/// 架构说明：
/// - 使用SharedPreferences保存工具栏位置
/// - 支持拖动位置和固定位置
/// - 提供loadPosition()和savePosition()方法
class ToolbarSettingsService {
  /// SharedPreferences键名
  static const String _key = 'toolbar_position';

  /// 加载工具栏位置设置
  ///
  /// 返回保存的工具栏位置设置，如果不存在则返回默认设置
  static Future<ToolbarPositionSetting> loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      return ToolbarPositionSetting.fromJson(jsonDecode(json));
    }
    return const ToolbarPositionSetting();
  }

  /// 保存工具栏位置设置
  ///
  /// [setting] 要保存的工具栏位置设置
  static Future<void> savePosition(ToolbarPositionSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(setting.toJson()));
  }
}
