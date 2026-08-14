import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../settings_hook_base.dart';

/// Settings Dialog
///
/// Main settings dialog providing access to storage, language, theme, and plugin settings.
class SettingsDialog extends StatefulWidget {
  /// Creates a settings dialog.
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsDialogState();

  @override
  Widget build(BuildContext context) {
    final storagePathService = context.watch<StoragePathService>();
    final themeService = context.watch<ThemeService>();
    final theme = themeService.themeData;
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
            _buildSectionHeader(i18n.t('Storage Settings')),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(i18n.t('Storage Location')),
              subtitle: Text(
                storagePathService.isUsingDefaultPath
                    ? i18n.t('Default Location')
                    : storagePathService.customStoragePath ?? i18n.t('Default Location'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showStoragePathSelector(context, storagePathService),
            ),
            FutureBuilder<StorageUsage>(
              future: storagePathService.getStorageUsage(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final usage = snapshot.data;
                  return ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: Text(i18n.t('Storage Usage')),
                    subtitle: Text(
                      '${usage?.formattedSize} • ${usage?.nodesCount} nodes • ${usage?.graphsCount} graphs',
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

            _buildSectionHeader(i18n.t('Language Settings')),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(i18n.t('Language')),
              subtitle: Text(_getCurrentLanguageLabel(i18n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageSelector(context),
            ),

            const Divider(height: 32),

            _buildSectionHeader(i18n.t('Theme Settings')),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(i18n.t('Color Theme')),
              subtitle: Text(_getThemeModeLabel(themeService.themeMode, i18n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context, themeService),
            ),
            ListTile(
              leading: const Icon(Icons.font_download_outlined),
              title: Text(i18n.t('Font')),
              subtitle: Text(_getFontFamilyLabel(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFontSelector(context),
            ),

            const Divider(height: 32),

            _buildSectionHeader(i18n.t('Plugin Settings')),
            ..._buildPluginSettings(context),

            const Divider(height: 32),

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
    StoragePathService storagePathService,
  ) async {
    final i18n = I18n.of(context);
    final currentPath = await storagePathService.getStoragePath();

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
            if (!storagePathService.isUsingDefaultPath)
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
                    await storagePathService.setCustomStoragePath(null);
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
                final newPath = await storagePathService.selectStoragePath();
                if (newPath != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${i18n.t('Storage location changed to:')} $newPath'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: i18n.t('Restart'),
                        onPressed: () {
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
    ThemeService themeService,
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
            groupValue: themeService.themeMode,
            onChanged: (value) {
              if (value != null) {
                themeService.setThemeMode(value);
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

  List<Widget> _buildPluginSettings(BuildContext context) {
    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('settings');
    final settingsRegistry = context.read<SettingsRegistry>();
    final hookContext = SettingsHookContext(
      data: {
        'buildContext': context,
        'settingsRegistry': settingsRegistry,
      },
      pluginContext: null,
      hookAPIRegistry: registry.apiRegistry,
    );

    return hookWrappers.map<Widget>((hookWrapper) {
      final hook = hookWrapper.hook;
      if (hook.isVisible(hookContext)) {
        return hook.render(hookContext);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  String _getCurrentLanguageLabel(I18n i18n) {
    final info = i18n.getLanguageInfo(i18n.currentLanguage);
    return info?.nativeName ?? i18n.currentLanguage;
  }

  void _showLanguageSelector(BuildContext context) {
    final i18n = I18n.of(context);
    final languages = i18n.supportedLanguages;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Select Language')),
          content: SizedBox(
            width: 300,
            child: RadioGroup<String>(
              groupValue: i18n.currentLanguage,
              onChanged: (value) {
                if (value != null) {
                  i18n.switchLanguage(value);
                  Navigator.pop(ctx);
                }
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final langCode = languages[index];
                  final langInfo = i18n.getLanguageInfo(langCode);

                  return RadioListTile<String>(
                    title: Text(langInfo?.nativeName ?? langCode),
                    subtitle: Text(langInfo?.name ?? langCode),
                    value: langCode,
                  );
                },
              ),
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

  String _getFontFamilyLabel(BuildContext context) {
    final themeService = context.read<ThemeService>();
    final fontFamily = themeService.themeData.fontFamily;
    if (fontFamily == null || fontFamily.isEmpty) {
      return 'System Default';
    }
    return fontFamily;
  }

  void _showFontSelector(BuildContext context) {
    final themeService = context.read<ThemeService>();
    final i18n = I18n.of(context);

    final fonts = [
      null,
      'Microsoft YaHei',
      'SimSun',
      'KaiTi',
      'SimHei',
      'FangSong',
      'Arial',
      'Calibri',
      'Cambria',
      'Consolas',
      'Segoe UI',
      'Times New Roman',
      'Courier New',
      'Verdana',
      'Georgia',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<ThemeService>().themeData;
        final currentFont = themeService.themeData.fontFamily;

        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text(i18n.t('Select Font')),
          content: SizedBox(
            width: 400,
            height: 300,
            child: RadioGroup<String?>(
              groupValue: currentFont,
              onChanged: (value) async {
                if (value != null) {
                  await themeService.updateCustomTheme(fontFamily: value);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: ListView.builder(
                itemCount: fonts.length,
                itemBuilder: (context, index) {
                  final font = fonts[index];
                  final fontName = font ?? 'System Default';

                  return RadioListTile<String?>(
                    title: Text(
                      fontName,
                      style: TextStyle(fontFamily: font),
                    ),
                    subtitle: font != null
                        ? Text(
                            'Sample Text 示例文字',
                            style: TextStyle(fontFamily: font, fontSize: 12),
                          )
                        : null,
                    value: font,
                  );
                },
              ),
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
}
