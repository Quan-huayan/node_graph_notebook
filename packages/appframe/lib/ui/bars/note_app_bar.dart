import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../hooks/hook_contexts.dart';

/// 应用程序的顶部导航栏
///
/// 通过钩子系统动态构建工具栏内容
class NoteAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  /// 创建一个应用程序顶部导航栏
  const NoteAppBarWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('main.toolbar');

    return AppBar(
      title: const Text('Node Graph Notebook'),
      actions: [
        // 动态加载所有主工具栏钩子
        ...hookWrappers.map((hookWrapper) {
          final hook = hookWrapper.hook;
          final hookContext = MainToolbarHookContext(
            data: {'buildContext': context},
            pluginContext: hookWrapper.parentPlugin?.context,
            hookAPIRegistry: registry.apiRegistry,
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
