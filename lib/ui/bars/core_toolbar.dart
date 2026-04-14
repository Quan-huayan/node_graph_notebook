import 'package:flutter/material.dart';

import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';
import '../../core/utils/logger.dart';

const _log = AppLogger('CoreToolbar');

/// 核心工具栏组件
///
/// 通过钩子系统动态构建工具栏内容
class CoreToolbar extends StatelessWidget implements PreferredSizeWidget {
  /// 创建核心工具栏
  const CoreToolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => _buildDefaultToolbar(context);

  /// 构建默认 Toolbar（当 Hook 不存在时使用）
  Widget _buildDefaultToolbar(BuildContext context) => AnimatedBuilder(
      animation: hookRegistry,
      builder: (context, child) {
        final hookWrappers = hookRegistry.getHookWrappers('main.toolbar');

        _log.info('build() called:');
        debugPrint('  - MainToolbar hooks found: ${hookWrappers.length}');

        return AppBar(
          title: const Text('Node Graph Notebook'),
          actions: [
            // 动态加载所有主工具栏钩子
            // 反转列表以保持正确的视觉顺序（从左到右）
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
            }).whereType<Widget>().toList().reversed,
          ],
        );
      },
    );
}
