import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/models.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';
import '../../core/services/i18n.dart';
import '../../core/services/services.dart';
import '../bloc/ui_bloc.dart';
import '../bloc/ui_event.dart';

/// 设置对话框
class SettingsDialog extends StatefulWidget {
  /// 创建设置对话框
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsDialogState();

  @override
  Widget build(BuildContext context) {
    final uiBloc = context.watch<UIBloc>();
    final uiState = uiBloc.state;
    final settingsService = context.watch<SettingsService>();
    final theme = context.watch<ThemeService>().themeData;
    final i18n = I18n.of(context);

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: Row(
        children: [const Icon(Icons.settings), const SizedBox(width: 8), Text(i18n.t('Settings'))],
      ),
      content: SizedBox(
        width: 500,
        child: ListView(
          shrinkWrap: true,
          children: [
            // 存储设置部分
            _buildSectionHeader(i18n.t('Storage Settings')),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(i18n.t('Storage Location')),
              subtitle: Text(
                settingsService.isUsingDefaultPath
                    ? i18n.t('Default Location')
                    : settingsService.customStoragePath ?? i18n.t('Default Location'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showStoragePathSelector(context, settingsService),
            ),
            FutureBuilder<StorageUsage>(
              future: settingsService.getStorageUsage(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final usage = snapshot.data!;
                  return ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: Text(i18n.t('Storage Usage')),
                    subtitle: Text(
                      '${usage.formattedSize} • ${usage.nodesCount} nodes • ${usage.graphsCount} graphs',
                    ),
                  );
                }
                return ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(i18n.t('Storage Usage')),
                  subtitle: Text(i18n.t('calculating')),
                );
              },
            ),

            const Divider(height: 32),

            // 主题设置部分
            _buildSectionHeader(i18n.t('Theme Settings')),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(i18n.t('Color Theme')),
              subtitle: Text(_getThemeModeLabel(settingsService.themeMode, i18n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context, settingsService),
            ),

            const Divider(height: 32),

            // 视图设置部分
            _buildSectionHeader(i18n.t('View Settings')),
            SwitchListTile(
              title: Text(i18n.t('Show Connections')),
              subtitle: Text(i18n.t('Display connection lines between nodes')),
              value: uiState.showConnections,
              onChanged: (value) {
                uiBloc.add(UISetConnectionsEvent(value));
              },
            ),
            SwitchListTile(
              title: Text(i18n.t('Show Sidebar')),
              subtitle: Text(i18n.t('Display the node list sidebar')),
              value: uiState.isSidebarOpen,
              onChanged: (value) {
                uiBloc.add(UISetSidebarEvent(value));
              },
            ),

            const Divider(height: 32),

            // 节点设置部分
            _buildSectionHeader(i18n.t('Node Settings')),
            ListTile(
              title: Text(i18n.t('Default View Mode')),
              subtitle: Text(_getViewModeLabel(uiState.defaultViewMode, i18n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showViewModeSelector(context),
            ),

            const Divider(height: 32),

            // 插件设置部分（通过Hook动态加载）
            _buildSectionHeader(i18n.t('Plugin Settings')),
            ..._buildPluginSettings(context, settingsService),

            const Divider(height: 32),

            // 关于部分
            _buildSectionHeader(i18n.t('About')),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(i18n.t('Node Graph Notebook')),
              subtitle: Text(i18n.t('Version 0.1.0')),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(i18n.t('Documentation')),
              subtitle: Text(i18n.t('View project documentation')),
              onTap: () {
                _showDocumentationDialog(context);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('Close')),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

  String _getViewModeLabel(NodeViewMode mode, I18n i18n) {
    switch (mode) {
      case NodeViewMode.titleOnly:
        return i18n.t('Title Only');
      case NodeViewMode.titleWithPreview:
        return i18n.t('Title with Preview');
      case NodeViewMode.fullContent:
        return i18n.t('Full Content');
      case NodeViewMode.compact:
        return i18n.t('Compact');
    }
  }

  void _showViewModeSelector(BuildContext context) {
    final uiBloc = context.read<UIBloc>();
    final currentMode = uiBloc.state.nodeViewMode;
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Select Default View Mode')),
          content: RadioGroup<NodeViewMode>(
            groupValue: currentMode,
            onChanged: (value) {
              if (value != null) {
                uiBloc.add(UISetDefaultViewModeEvent(value));
                Navigator.pop(ctx);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: NodeViewMode.values.map((mode) => RadioListTile<NodeViewMode>(
                  title: Text(_getViewModeLabel(mode, i18n)),
                  value: mode,
                )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('Cancel')),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('About Node Graph Notebook')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  i18n.t('Node Graph Notebook'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(i18n.t('Version 0.1.0')),
                const SizedBox(height: 16),
                Text(
                  i18n.t('A concept map-based note-taking application built with Flutter and Flame engine.'),
                ),
                const SizedBox(height: 16),
                Text(
                  i18n.t('Features:'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• ${i18n.t('Visual node graph with Flame engine')}'),
                Text('• ${i18n.t('Markdown editing support')}'),
                Text('• ${i18n.t('Multiple node types (Content & Concept)')}'),
                Text('• ${i18n.t('8 reference types for relationships')}'),
                Text('• ${i18n.t('Auto-layout algorithms')}'),
                Text('• ${i18n.t('Search and filter functionality')}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('Close')),
            ),
          ],
        );
      },
    );
  }

  void _showDocumentationDialog(BuildContext context) {
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Documentation')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  i18n.t('Quick Start Guide'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  i18n.t('1. Creating Nodes'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• ${i18n.t('Click the + button to create a new node')}'),
                Text('• ${i18n.t('Choose between Content or Concept node type')}'),
                Text('• ${i18n.t('Enter title and content')}'),
                const SizedBox(height: 16),
                Text(
                  i18n.t('2. Connecting Nodes'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• ${i18n.t('Long press a node to open its menu')}'),
                Text('• ${i18n.t('Select "Connect to..." to link nodes')}'),
                Text('• ${i18n.t('Choose a reference type for the connection')}'),
                const SizedBox(height: 16),
                Text(
                  i18n.t('3. Layout Options'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• ${i18n.t('Force Directed: Physics-based layout')}'),
                Text('• ${i18n.t('Hierarchical: Tree-based layout')}'),
                Text('• ${i18n.t('Circular: Circle arrangement')}'),
                Text('• ${i18n.t('Concept Map: Concept-focused layout')}'),
                const SizedBox(height: 16),
                Text(
                  i18n.t('4. Keyboard Shortcuts'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• ${i18n.t('Ctrl+N: Create new node')}'),
                Text('• ${i18n.t('Ctrl+S: Save current node')}'),
                Text('• ${i18n.t('Ctrl+F: Quick search')}'),
                Text('• ${i18n.t('Delete: Delete selected node')}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('Close')),
            ),
          ],
        );
      },
    );
  }

  void _showStoragePathSelector(
    BuildContext context,
    SettingsService settingsService,
  ) async {
    final i18n = I18n.of(context);
    final currentPath = await settingsService.getStoragePath();

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Storage Location')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.t('Current Location:'),
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                currentPath,
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                i18n.t('Choose a new storage location. All data will be stored in this location.'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                i18n.t('Warning: Changing the storage location will require restarting the app.'),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: context.read<ThemeService>().themeData.status.warning,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('Cancel')),
            ),
            if (!settingsService.isUsingDefaultPath)
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      final theme = ctx.read<ThemeService>().themeData;
                      return AlertDialog(
                        backgroundColor: theme.backgrounds.primary,
                        title: Text(i18n.t('Reset to Default')),
                        content: Text(i18n.t(
                          'Reset to default storage location?',
                        )),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(i18n.t('Cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(i18n.t('Reset')),
                          ),
                        ],
                      );
                    },
                  );

                  if ((confirmed ?? false) && context.mounted) {
                    await settingsService.setCustomStoragePath(null);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          i18n.t('Storage location reset. Please restart the app.'),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: Text(i18n.t('Reset to Default')),
              ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final newPath = await settingsService.selectStoragePath();
                if (newPath != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${i18n.t('Storage location changed to:')} $newPath'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: i18n.t('Restart'),
                        onPressed: () {
                          // 提示用户需要重启应用
                        },
                      ),
                    ),
                  );
                }
              },
              child: Text(i18n.t('Choose New Location')),
            ),
          ],
        );
      },
    );
  }

  void _showThemeSelector(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final i18n = I18n.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Select Theme')),
          content: RadioGroup<ThemeMode>(
            groupValue: settingsService.themeMode,
            onChanged: (value) {
              if (value != null) {
                settingsService.setThemeMode(value);
                Navigator.pop(ctx);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(i18n.t('Light')),
                  subtitle: Text(i18n.t('Always use light theme')),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(i18n.t('Dark')),
                  subtitle: Text(i18n.t('Always use dark theme')),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(i18n.t('System')),
                  subtitle: Text(i18n.t('Follow system settings')),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('Cancel')),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildPluginSettings(BuildContext context, SettingsService settingsService) {
    final hookWrappers = hookRegistry.getHookWrappers('settings');
    final hookContext = SettingsHookContext(
      data: {
        'buildContext': context,
        'settingsService': settingsService,
      },
      pluginContext: null,
      hookAPIRegistry: hookRegistry.apiRegistry,
    );

    return hookWrappers.map<Widget>((hookWrapper) {
      final hook = hookWrapper.hook;
      if (hook.isVisible(hookContext)) {
        return hook.render(hookContext);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  String _getThemeModeLabel(ThemeMode mode, I18n i18n) {
    switch (mode) {
      case ThemeMode.light:
        return i18n.t('Light');
      case ThemeMode.dark:
        return i18n.t('Dark');
      case ThemeMode.system:
        return i18n.t('System');
    }
  }
}
