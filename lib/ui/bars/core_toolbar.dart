import 'package:flutter/material.dart';

import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_point.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';

/// 核心工具栏组件
///
/// 通过钩子系统动态构建工具栏内容
class CoreToolbar extends StatelessWidget implements PreferredSizeWidget {
  /// 创建核心工具栏
  const CoreToolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final hooks = hookRegistry.getHooks(HookPointId.mainToolbar);

    return AppBar(
      title: const Text('Node Graph Notebook'),
      actions: [
        // 动态加载所有主工具栏钩子
        ...hooks.map((hook) {
          final hookContext = MainToolbarHookContext(
            data: {'buildContext': context},
          );
          if (hook.isVisible(hookContext)) {
            return hook.render(hookContext);
          }
          return null;
        }).whereType<Widget>(),
      ],
    );
  }
}
