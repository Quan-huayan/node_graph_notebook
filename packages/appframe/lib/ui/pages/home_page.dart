import 'package:core/core.dart';
import 'package:core/plugin/hook/rendering/flutter_renderer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 主页面
///
/// 应用的主页面，包含核心工具栏、侧边栏和图形视图
class HomePage extends StatefulWidget {
  /// 创建一个主页面
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    final layoutService = Provider.of<UILayoutService>(context, listen: false);

    return Consumer<HookRoleRegistry>(
      builder: (context, hookRoleRegistry, child) =>
          FlutterRenderer(hookRoleRegistry: hookRoleRegistry)
          .render(layoutService.rootHook, {'buildContext': context}),
    );
  }
}