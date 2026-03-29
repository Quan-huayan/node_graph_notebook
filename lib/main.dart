import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/services.dart';
import 'core/utils/logger.dart';

const _log = AppLogger('Main');

// 主函数
void main() {
  // 在 runZonedGuarded 中运行应用以捕获所有异步错误
  // 必须在 zone 内初始化 Flutter 绑定，否则会产生 zone 不匹配警告
  runZonedGuarded(() async {
    // 确保 Flutter 绑定初始化
    WidgetsFlutterBinding.ensureInitialized();

    // 捕获所有错误（包括在 zone 外的错误）
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('════════════════════════════════════════');
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
      debugPrint('════════════════════════════════════════');
    };

    debugPrint('════════════════════════════════════════');
    debugPrint('Starting Node Graph Notebook...');
    debugPrint('════════════════════════════════════════');

    // 初始化设置服务
    _log.info('Initializing SettingsService...');
    final settingsService = SettingsService();
    await settingsService.init();
    _log.info('[Main] ✓ SettingsService initialized');

    // 初始化主题服务
    _log.info('Initializing ThemeService...');
    final themeService = ThemeService();
    await themeService.init();
    _log.info('[Main] ✓ ThemeService initialized');

    runApp(
      NodeGraphNotebookApp(
        settingsService: settingsService,
        themeService: themeService,
      ),
    );
  }, (error, stack) {
    debugPrint('════════════════════════════════════════');
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack trace: $stack');
    debugPrint('════════════════════════════════════════');
  });
}
