import 'package:flutter/material.dart';

import '../../../core/utils/logger.dart';

const _log = AppLogger('GlobalMessageService');

/// 全局消息显示服务
///
/// 用于在Lua脚本中显示消息对话框
class GlobalMessageService {
  /// 当前应用的context
  static BuildContext? _context;

  /// 设置当前context
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// 显示消息
  static void showMessage(String title, String message) {
    if (_context == null) {
      _log.info('No context available, showing in debug console only');
      debugPrint('[LUA MESSAGE] $title: $message');
      return;
    }

    // 使用ScaffoldMessenger显示SnackBar
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '确定',
          onPressed: () {},
        ),
      ),
    );
  }

  /// 显示警告
  static void showWarning(String message) {
    if (_context == null) {
      _log.info('No context available, showing in debug console only');
      debugPrint('[LUA WARNING] $message');
      return;
    }

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text('⚠️ $message'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// 显示错误
  static void showError(String message) {
    if (_context == null) {
      _log.info('No context available, showing in debug console only');
      debugPrint('[LUA ERROR] $message');
      return;
    }

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red,
      ),
    );
  }
}
