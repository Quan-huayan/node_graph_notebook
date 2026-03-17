import 'package:flutter/material.dart';

import '../../core/plugin/ui_hooks/hook_context.dart';
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
    final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');

    return AppBar(
      title: const Text('Node Graph Notebook'),
      actions: [
        // 动态加载所有主工具栏钩子
        ...hookWrappers.map((hookWrapper) {
          final hook = hookWrapper.hook;
          final hookContext = MainToolbarHookContext(
            data: {'buildContext': context},
            pluginContext: hookWrapper.parentPlugin?.context,
            hookAPIRegistry: hookRegistry.apiRegistry,
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
