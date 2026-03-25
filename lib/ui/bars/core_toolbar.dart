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
    // ✅ 监听 HookRegistry 变化，自动重新构建
    return AnimatedBuilder(
      animation: hookRegistry,
      builder: (context, child) {
        final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');

        debugPrint('[CoreToolbar] build() called:');
        debugPrint('  - MainToolbar hooks found: ${hookWrappers.length}');

        return AppBar(
          title: const Text('Node Graph Notebook'),
          actions: [
            // 动态加载所有主工具栏钩子
            ...hookWrappers.map((hookWrapper) {
              final hook = hookWrapper.hook;
              debugPrint('  - Rendering toolbar hook: ${hook.metadata.id}');
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
      },
    );
  }
}
