import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import 'ui/import_export_page.dart';

/// 导入导出工具栏钩子
class ConverterToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'converter_toolbar_hook',
    name: 'Converter Toolbar Hook',
    version: '1.0.0',
    description: 'Provides import/export button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.medium;

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
}
