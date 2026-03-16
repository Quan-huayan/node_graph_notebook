import 'package:flutter/material.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import 'ui/import_export_page.dart';

/// 导入导出工具栏钩子
class ConverterToolbarHook extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 30;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'converter_toolbar_hook',
    name: 'Converter Toolbar Hook',
    version: '1.0.0',
    description: 'Provides import/export button in toolbar',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.import_export),
      onPressed: () => _openImportExportPage(context),
      tooltip: 'Import & Export',
    );

  void _openImportExportPage(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    Navigator.push(
      buildContext,
      MaterialPageRoute(builder: (ctx) => const ImportExportPage()),
    );
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onUnload() async {}
}
