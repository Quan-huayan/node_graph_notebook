import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/services/i18n.dart';
import '../../plugins/ai/ui/ai_config_dialog.dart';
import '../../plugins/ai/ui/ai_test_dialog.dart';
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
        children: [Icon(Icons.settings), SizedBox(width: 8), Text(i18n.t('Settings'))],
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
                  subtitle: Text('Calculating...'),
                );
              },
            ),

            const Divider(height: 32),

            // 主题设置部分
            _buildSectionHeader(i18n.t('Theme Settings')),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(i18n.t('Color Theme')),
              subtitle: Text(_getThemeModeLabel(settingsService.themeMode)),
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
              subtitle: Text(_getViewModeLabel(uiState.defaultViewMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showViewModeSelector(context),
            ),

            const Divider(height: 32),

            // AI 配置部分
            _buildSectionHeader(i18n.t('AI Configuration')),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(i18n.t('AI Settings')),
              subtitle: Text(
                settingsService.isAIConfigured
                    ? '${settingsService.aiProvider} - ${settingsService.aiModel}'
                    : 'Not configured',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAIConfigDialog(context, settingsService),
            ),
            if (settingsService.isAIConfigured)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(i18n.t('Test AI Connection')),
                subtitle: Text(i18n.t('Chat with AI to test the configuration')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAITestDialog(context),
              ),

            const Divider(height: 32),

            // 关于部分
            _buildSectionHeader(i18n.t('About')),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Node Graph Notebook'),
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

  String _getViewModeLabel(NodeViewMode mode) {
    switch (mode) {
      case NodeViewMode.titleOnly:
        return 'Title Only';
      case NodeViewMode.titleWithPreview:
        return 'Title with Preview';
      case NodeViewMode.fullContent:
        return 'Full Content';
      case NodeViewMode.compact:
        return 'Compact';
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
                  title: Text(_getViewModeLabel(mode)),
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
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Node Graph Notebook',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Version 0.1.0'),
                SizedBox(height: 16),
                Text(
                  'A concept map-based note-taking application built with Flutter and Flame engine.',
                ),
                SizedBox(height: 16),
                Text(
                  'Features:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Visual node graph with Flame engine'),
                Text('• Markdown editing support'),
                Text('• Multiple node types (Content & Concept)'),
                Text('• 8 reference types for relationships'),
                Text('• Auto-layout algorithms'),
                Text('• Search and filter functionality'),
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
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quick Start Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  '1. Creating Nodes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Click the + button to create a new node'),
                Text('• Choose between Content or Concept node type'),
                Text('• Enter title and content'),
                SizedBox(height: 16),
                Text(
                  '2. Connecting Nodes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Long press a node to open its menu'),
                Text('• Select "Connect to..." to link nodes'),
                Text('• Choose a reference type for the connection'),
                SizedBox(height: 16),
                Text(
                  '3. Layout Options',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Force Directed: Physics-based layout'),
                Text('• Hierarchical: Tree-based layout'),
                Text('• Circular: Circle arrangement'),
                Text('• Concept Map: Concept-focused layout'),
                SizedBox(height: 16),
                Text(
                  '4. Keyboard Shortcuts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Ctrl+N: Create new node'),
                Text('• Ctrl+S: Save current node'),
                Text('• Ctrl+F: Quick search'),
                Text('• Delete: Delete selected node'),
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
                'Current Location:',
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
              const Text(
                'Choose a new storage location. All data will be stored in this location.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Warning: Changing the storage location will require restarting the app.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: context.read<ThemeService>().themeData.status.warning,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
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
                      const SnackBar(
                        content: Text(
                          'Storage location reset. Please restart the app.',
                        ),
                        duration: Duration(seconds: 3),
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
                      content: Text('Storage location changed to: $newPath'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'Restart',
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
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  subtitle: Text('Always use light theme'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  subtitle: Text('Always use dark theme'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('System'),
                  subtitle: Text('Follow system settings'),
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

  void _showAIConfigDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AIConfigDialog(settingsService: settingsService),
    );
  }

  void _showAITestDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const AITestDialog());
  }
}

String _getThemeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System';
  }
}
