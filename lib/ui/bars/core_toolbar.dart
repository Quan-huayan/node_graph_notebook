import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/feature_flags.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';
import '../../core/ui_layout/rendering/flutter_renderer.dart';
import '../../core/ui_layout/ui_layout_service.dart';
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
  Widget build(BuildContext context) {
    // 检查是否启用新的UI布局系统
    if (LayoutFeatureFlags.useNewLayoutSystem ||
        LayoutFeatureFlags.useNewLayoutSystemForToolbar) {
      return _buildNewToolbar(context);
    }

    // 使用旧的HookRegistry实现
    return _buildLegacyToolbar(context);
  }

  /// 使用新的UILayoutService系统构建Toolbar
  Widget _buildNewToolbar(BuildContext context) {
    try {
      final layoutService = context.read<UILayoutService>();
      final renderer = FlutterRenderer();
      final toolbarHook = layoutService.getHook('main.toolbar');

      if (toolbarHook != null) {
        return SizedBox(
          height: preferredSize.height,
          child: renderer.render(toolbarHook, {'buildContext': context}),
        );
      }

      // 如果Hook不存在，回退到旧实现
      return _buildLegacyToolbar(context);
    } catch (e) {
      _log.warning('Failed to use new layout system, falling back: $e');
      return _buildLegacyToolbar(context);
    }
  }

  /// 使用旧的HookRegistry系统构建Toolbar
  Widget _buildLegacyToolbar(BuildContext context)
    // ✅ 监听 HookRegistry 变化，自动重新构建
    => AnimatedBuilder(
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
