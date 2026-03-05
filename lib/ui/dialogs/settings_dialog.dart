import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../models/models.dart';

/// 设置对话框
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsDialogState();

  @override
  Widget build(BuildContext context) {
    final uiModel = context.watch<UIModel>();
    final settingsService = context.watch<SettingsService>();
    final theme = context.watch<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Settings'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: ListView(
          shrinkWrap: true,
          children: [
            // 存储设置部分
            _buildSectionHeader('Storage Settings'),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Storage Location'),
              subtitle: Text(
                settingsService.isUsingDefaultPath
                    ? 'Default Location'
                    : settingsService.customStoragePath ?? 'Default Location',
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
                    title: const Text('Storage Usage'),
                    subtitle: Text(
                      '${usage.formattedSize} • ${usage.nodesCount} nodes • ${usage.graphsCount} graphs',
                    ),
                  );
                }
                return const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Storage Usage'),
                  subtitle: Text('Calculating...'),
                );
              },
            ),

            const Divider(height: 32),

            // 主题设置部分
            _buildSectionHeader('Theme Settings'),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Color Theme'),
              subtitle: Text(_getThemeModeLabel(settingsService.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context, settingsService),
            ),

            const Divider(height: 32),

            // 视图设置部分
            _buildSectionHeader('View Settings'),
            SwitchListTile(
              title: const Text('Show Connections'),
              subtitle: const Text('Display connection lines between nodes'),
              value: uiModel.showConnections,
              onChanged: (value) {
                uiModel.setConnections(value);
              },
            ),
            SwitchListTile(
              title: const Text('Show Concept Nodes'),
              subtitle: const Text('Display concept nodes in the graph'),
              value: uiModel.showConceptNodes,
              onChanged: (value) {
                uiModel.setConceptNodes(value);
              },
            ),
            SwitchListTile(
              title: const Text('Show Sidebar'),
              subtitle: const Text('Display the node list sidebar'),
              value: uiModel.isSidebarOpen,
              onChanged: (value) {
                uiModel.setSidebar(value);
              },
            ),

            const Divider(height: 32),

            // 节点设置部分
            _buildSectionHeader('Node Settings'),
            ListTile(
              title: const Text('Default View Mode'),
              subtitle: Text(_getViewModeLabel(uiModel.defaultViewMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showViewModeSelector(context),
            ),

            const Divider(height: 32),

            // 关于部分
            _buildSectionHeader('About'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Node Graph Notebook'),
              subtitle: const Text('Version 0.1.0'),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Documentation'),
              subtitle: const Text('View project documentation'),
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
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Select Default View Mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: NodeViewMode.values.map((mode) {
              return RadioListTile<NodeViewMode>(
                title: Text(_getViewModeLabel(mode)),
                value: mode
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('About Node Graph Notebook'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(
                'Node Graph Notebook',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
            child: const Text('Close'),
          ),
        ],
      );
    });
  }

  void _showDocumentationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Documentation'),
          content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quick Start Guide',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
            child: const Text('Close'),
          ),
        ],
      );
    });
  }

  void _showStoragePathSelector(BuildContext context, SettingsService settingsService) async {
    final currentPath = await settingsService.getStoragePath();

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Storage Location'),
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
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
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
                      title: const Text('Reset to Default'),
                      content: const Text('Reset to default storage location?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed == true && context.mounted) {
                  await settingsService.setCustomStoragePath(null);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Storage location reset. Please restart the app.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: const Text('Reset to Default'),
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
            child: const Text('Choose New Location'),
          ),
        ],
      );
    });
  }

  void _showThemeSelector(BuildContext context, SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: const Text('Select Theme'),
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
            child: const Text('Cancel'),
          ),
        ],
      );
    });
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
}
