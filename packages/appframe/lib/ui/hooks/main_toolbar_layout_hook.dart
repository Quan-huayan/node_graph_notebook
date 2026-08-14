import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_service.dart';
import 'hook_bases.dart';
import 'hook_contexts.dart';

const _log = AppLogger('MainToolbarLayoutHook');

/// MainToolbar 布局 Hook
///
/// 实现主工具栏布局，包含标题和动态加载的 Hook 按钮
class MainToolbarLayoutHook extends MainToolbarLayoutHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'main.toolbar.layout',
    name: 'Main Toolbar Layout Hook',
    version: '1.0.0',
    description: 'Main toolbar layout with title and action buttons',
  );

  @override
  HookPriority get priority => HookPriority.critical;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) {
      return const Center(child: Text('No build context'));
    }

    return _MainToolbarLayoutWidget();
  }
}

class _MainToolbarLayoutWidget extends StatefulWidget {
  @override
  State<_MainToolbarLayoutWidget> createState() => _MainToolbarLayoutWidgetState();
}

class _MainToolbarLayoutWidgetState extends State<_MainToolbarLayoutWidget> {
  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final toolbarTheme = themeService.currentThemeData.mainToolbar;

    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('main.toolbar');
    _log.info('MainToolbar hooks found: ${hookWrappers.length}');

    return Container(
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: toolbarTheme.background,
        border: Border(
          bottom: BorderSide(
            color: toolbarTheme.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Node Graph Notebook',
                style: TextStyle(
                  color: toolbarTheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ...hookWrappers.map((hookWrapper) {
            final hook = hookWrapper.hook;
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
      ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: widget.hook.render(widget.hookContext),
        ),
      ),
    );
  }
}