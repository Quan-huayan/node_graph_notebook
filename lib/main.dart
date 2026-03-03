import 'package:flutter/material.dart';
import 'core/services/services.dart';
import 'app.dart';

// 主函数
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化设置服务
  final settingsService = SettingsService();
  await settingsService.init();

  // 初始化主题服务
  final themeService = ThemeService();
  await themeService.init();

  // 捕获 Flutter 错误
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  runApp(NodeGraphNotebookApp(
    settingsService: settingsService,
    themeService: themeService,
  ));
}
