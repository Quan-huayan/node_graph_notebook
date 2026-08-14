import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_service.dart';
import 'hook_bases.dart';
import 'hook_contexts.dart';

const _log = AppLogger('SidebarLayoutHook');

const double _activityBarWidth = 48;
const double _sidebarContentWidth = 240;

/// A hook that provides the sidebar layout with an activity bar and tab-based
/// content switching, supporting plugin-registered sidebar tabs.
class SidebarLayoutHook extends SidebarLayoutHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'sidebar.layout',
    name: 'Sidebar Layout Hook',
    version: '1.0.0',
    description: 'Sidebar layout with tab system',
  );

  @override
  HookPriority get priority => HookPriority.critical;

  @override
  Widget renderSidebar(SidebarLayoutHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) {
      return const Center(child: Text('No build context'));
    }

    final nodes = context.nodes;
    final folders = context.folders;

    return _SidebarLayoutWidget(
      nodes: nodes,
      folders: folders,
    );
  }
}

class _SidebarLayoutWidget extends StatefulWidget {
  const _SidebarLayoutWidget({
    required this.nodes,
    required this.folders,
  });

  final List<Node> nodes;
  final List<Node> folders;

  @override
  State<_SidebarLayoutWidget> createState() => _SidebarLayoutWidgetState();
}

class _SidebarLayoutWidgetState extends State<_SidebarLayoutWidget> {
  int _selectedTabIndex = 0;
  bool _isSidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final sidebarTheme = themeService.currentThemeData.sidebar;

    final tabHooks = _getTabHooks(context);

    if (tabHooks.isEmpty) {
      return _buildDefaultContent(context);
    }

    final visibleTabs = tabHooks.where((hook) {
      final hookContext = SidebarHookContext(
        data: {
          'nodes': widget.nodes,
          'folders': widget.folders,
          'buildContext': context,
        },
        hookAPIRegistry: context.read<HookRoleRegistry>().apiRegistry,
      );
      return hook.isTabVisible(hookContext);
    }).toList();

    if (visibleTabs.isEmpty) {
      return _buildDefaultContent(context);
    }

    final selectedTab = visibleTabs[_selectedTabIndex.clamp(0, visibleTabs.length - 1)];

    return Row(
      children: [
        _buildActivityBar(context, visibleTabs, sidebarTheme),
        if (_isSidebarExpanded)
          Container(
            width: _sidebarContentWidth,
            color: sidebarTheme.contentBackground,
            child: _buildTabContent(context, selectedTab),
          ),
      ],
    );
  }

  List<SidebarTabHookRole> _getTabHooks(BuildContext context) {
    final wrappers = context.read<HookRoleRegistry>().getHookWrappers('sidebar.tab');
    _log.info('Get the number of hooks: $wrappers');
    return wrappers
        .map((w) => w.hook)
        .whereType<SidebarTabHookRole>()
        .toList();
  }

  Widget _buildActivityBar(
    BuildContext context,
    List<SidebarTabHookRole> tabs,
    SidebarThemeColors sidebarTheme,
  ) => Container(
      width: _activityBarWidth,
      color: sidebarTheme.activityBarBackground,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = index == _selectedTabIndex;

                return _ActivityBarButton(
                  tab: tab,
                  isSelected: isSelected,
                  sidebarTheme: sidebarTheme,
                  onTap: () {
                    if (isSelected && _isSidebarExpanded) {
                      setState(() => _isSidebarExpanded = false);
                    } else {
                      setState(() {
                        _selectedTabIndex = index;
                        _isSidebarExpanded = true;
                      });
                    }
                  },
                );
              },
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: sidebarTheme.contentBorder,
          ),
          _ActivityBarButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            sidebarTheme: sidebarTheme,
            isSelected: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon...')),
              );
            },
          ),
        ],
      ),
    );

  Widget _buildTabContent(BuildContext context, SidebarTabHookRole tab) {
    final hookContext = SidebarHookContext(
      data: {
        'nodes': widget.nodes,
        'folders': widget.folders,
        'buildContext': context,
      },
      hookAPIRegistry: context.read<HookRoleRegistry>().apiRegistry,
    );

    return tab.buildContent(hookContext);
  }

  Widget _buildDefaultContent(BuildContext context) {
    final i18n = I18n.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(i18n.t('No plugins')),
          const SizedBox(height: 8),
          Text(
            '${widget.nodes.length} nodes, ${widget.folders.length} folders',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActivityBarButton extends StatefulWidget {
  const _ActivityBarButton({
    required this.sidebarTheme,
    required this.isSelected,
    required this.onTap,
    this.tab,
    this.icon,
    this.tooltip,
  });

  final SidebarTabHookRole? tab;
  final IconData? icon;
  final String? tooltip;
  final SidebarThemeColors sidebarTheme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ActivityBarButton> createState() => _ActivityBarButtonState();
}

class _ActivityBarButtonState extends State<_ActivityBarButton> {
  bool _isHovered = false;

  IconData get _icon => widget.tab?.tabIcon ?? widget.icon ?? Icons.error;
  String get _tooltip => widget.tab?.tabLabel ?? widget.tooltip ?? '';

  @override
  Widget build(BuildContext context) {
    final sidebarTheme = widget.sidebarTheme;
    final iconColor = widget.isSelected
        ? sidebarTheme.activityBarIconSelected
        : sidebarTheme.activityBarIcon;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: _activityBarWidth,
          height: _activityBarWidth,
          color: _isHovered ? sidebarTheme.activityBarHover : null,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  _icon,
                  size: 24,
                  color: iconColor,
                ),
              ),
              if (widget.isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: sidebarTheme.activityBarIndicator,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}