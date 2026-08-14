import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_service.dart';
import '../hooks/hook_contexts.dart';

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
  Widget _buildDefaultToolbar(BuildContext context) {
    final registry = context.read<HookRoleRegistry>();
    return AnimatedBuilder(
      animation: registry,
      builder: (context, child) {
        final themeService = context.watch<ThemeService>();
        final toolbarTheme = themeService.currentThemeData.mainToolbar;
        final hookWrappers = registry.getHookWrappers('main.toolbar');

        _log.info('build() called:');
        debugPrint('  - MainToolbar hooks found: ${hookWrappers.length}');

        return AppBar(
          title: Text(
            'Node Graph Notebook',
            style: TextStyle(color: toolbarTheme.foreground),
          ),
          backgroundColor: toolbarTheme.background,
          iconTheme: IconThemeData(color: toolbarTheme.icon),
          actionsIconTheme: IconThemeData(color: toolbarTheme.icon),
          actions: [
            ...hookWrappers.map((hookWrapper) {
              final hook = hookWrapper.hook;
              debugPrint('  - Rendering toolbar hook: ${hook.metadata.id}');
              final hookContext = MainToolbarHookContext(
                data: {'buildContext': context},
                pluginContext: hookWrapper.parentPlugin?.context,
                hookAPIRegistry: registry.apiRegistry,
              );
              if (hook.isVisible(hookContext)) {
                return _ToolbarActionButton(
                  hook: hook,
                  hookContext: hookContext,
                  toolbarTheme: toolbarTheme,
                );
              }
              return null;
            }).whereType<Widget>().toList().reversed,
          ],
        );
      },
    );
  }
}

class _ToolbarActionButton extends StatefulWidget {
  const _ToolbarActionButton({
    required this.hook,
    required this.hookContext,
    required this.toolbarTheme,
  });

  final HookRoleBase hook;
  final MainToolbarHookContext hookContext;
  final MainToolbarThemeColors toolbarTheme;

  @override
  State<_ToolbarActionButton> createState() => _ToolbarActionButtonState();
}

class _ToolbarActionButtonState extends State<_ToolbarActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = _isHovered
        ? widget.toolbarTheme.iconHover
        : widget.toolbarTheme.icon;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IconTheme(
        data: IconThemeData(color: iconColor),
        child: widget.hook.render(widget.hookContext),
      ),
    );
  }
}
